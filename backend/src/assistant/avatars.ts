import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { AuthUser } from '../domain/dto.js';
import { CHARACTERS, characterById } from './characters.js';
import type { AssistantCharacter } from './characters.js';
import { CreditsService } from './credits.service.js';
import { LLM_PROVIDER, LlmError } from './llm.js';
import type { ImageData, LlmProvider } from './llm.js';

export const POSES = ['neutral', 'thinking', 'celebrating', 'concerned'] as const;
export type Pose = (typeof POSES)[number];

export const CUSTOM_ID = 'custom';
export const MAX_PHOTO_BYTES = 5_000_000;
export const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/** The same look as the five presets, so a custom character sits beside them. */
const STYLE = [
  'Semi-realistic 3D character render, full body, standing, head to toe with both feet visible,',
  'centered, facing the viewer at a slight angle. Football manager outfit with an electric lime-green',
  '(#B8FF3C) accent. Soft studio lighting, subtle lime-green rim light from behind. Plain solid very dark',
  'green (#0A1410) background, small soft shadow under the feet only. Head in the upper fifth of the frame,',
  'figure filling about 90% of the height. Portrait 2:3. No text, no logos.',
].join(' ');

const POSE_PROMPTS: Record<Exclude<Pose, 'neutral'>, string> = {
  thinking: 'thinking: looking up and to the side, one hand on the chin.',
  celebrating: 'celebrating: big open smile, one fist raised.',
  concerned: 'concerned: brows furrowed, lips pressed, arms folded.',
};

export interface UploadedPhoto {
  buffer: Buffer;
  mimetype: string;
  size: number;
}

/**
 * Custom Assistant Managers drawn from the Manager's own photo.
 *
 * The photo is used once, in memory, to draw a character in the presets'
 * style; four poses are then drawn from that character. Only those drawings
 * are kept. The first is free; later ones cost credits, refunded if drawing
 * fails (which is also what happens when the model's safety filters decline
 * a photo).
 */
@Injectable()
export class AvatarService {
  private readonly logger = new Logger(AvatarService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(LLM_PROVIDER) private readonly llm: LlmProvider,
    private readonly credits: CreditsService,
  ) {}

  /** What the next custom avatar costs this Manager: 0 for their first. */
  async cost(userId: string): Promise<number> {
    const row = await this.db
      .selectFrom('assistant_profiles')
      .select('free_avatar_used')
      .where('user_id', '=', userId)
      .executeTakeFirst();
    return row?.free_avatar_used ? this.config.assistantAvatarCredits : 0;
  }

  async create(
    user: AuthUser,
    photo: UploadedPhoto | undefined,
    body: { personality?: unknown; name?: unknown; consent?: unknown },
  ): Promise<{ credits: number }> {
    if (!photo) throw new BadRequestException('Add a photo');
    if (!PHOTO_TYPES.includes(photo.mimetype)) throw new BadRequestException('Use a JPEG, PNG or WebP photo');
    if (photo.size > MAX_PHOTO_BYTES) throw new BadRequestException('That photo is too large (5 MB max)');
    if (body.consent !== 'true' && body.consent !== true) {
      throw new BadRequestException('Confirm the photo is of you, or that you have permission to use it');
    }
    const personality = characterById(typeof body.personality === 'string' ? body.personality : undefined);
    if (!personality) throw new BadRequestException('Pick a personality for your Assistant Manager');
    const name = typeof body.name === 'string' && body.name.trim() ? body.name.trim().slice(0, 24) : null;
    if (!this.llm.available) throw new ServiceUnavailableException('Drawing avatars is not available right now');

    const cost = await this.cost(user.id);
    let balance = await this.credits.balance(user.id);
    if (cost > 0) {
      const charged = await this.credits.charge(user.id, cost, 'avatar');
      if (charged === null) {
        throw new HttpException(`A new avatar costs ${cost} credits`, HttpStatus.PAYMENT_REQUIRED);
      }
      balance = charged;
    }

    let poses: Map<Pose, ImageData>;
    try {
      poses = await this.draw({ mime: photo.mimetype, data: photo.buffer });
    } catch (e) {
      if (cost > 0) await this.credits.refund(user.id, cost, 'avatar');
      this.logger.warn(`Avatar drawing failed: ${e instanceof LlmError ? e.message : String(e)}`);
      throw new BadGatewayException(
        "We couldn't draw an Assistant Manager from that photo. Try a clear, well-lit photo of one person." +
          (cost > 0 ? ' You were not charged.' : ''),
      );
    }

    await this.db.transaction().execute(async (trx) => {
      await trx.deleteFrom('assistant_avatars').where('user_id', '=', user.id).execute();
      await trx
        .insertInto('assistant_avatars')
        .values([...poses].map(([pose, image]) => ({ user_id: user.id, pose, mime: image.mime, image: image.data })))
        .execute();
      await trx
        .insertInto('assistant_profiles')
        .values({
          user_id: user.id,
          character_id: CUSTOM_ID,
          personality: personality.id,
          custom_name: name,
          free_avatar_used: true,
        })
        .onConflict((oc) =>
          oc.column('user_id').doUpdateSet({
            character_id: CUSTOM_ID,
            personality: personality.id,
            custom_name: name,
            free_avatar_used: true,
            updated_at: this.clock.date(),
          }),
        )
        .execute();
    });
    return { credits: balance };
  }

  async image(user: AuthUser, pose: string): Promise<ImageData> {
    if (!(POSES as readonly string[]).includes(pose)) throw new NotFoundException('No such pose');
    const row = await this.db
      .selectFrom('assistant_avatars')
      .select(['mime', 'image'])
      .where('user_id', '=', user.id)
      .where('pose', '=', pose as Pose)
      .executeTakeFirst();
    if (!row) throw new NotFoundException('No custom avatar yet');
    return { mime: row.mime, data: row.image };
  }

  /** When the Manager's avatar was drawn, for cache-busting; null if they have none. */
  async drawnAt(userId: string): Promise<number | null> {
    const row = await this.db
      .selectFrom('assistant_avatars')
      .select('created_at')
      .where('user_id', '=', userId)
      .where('pose', '=', 'neutral')
      .executeTakeFirst();
    return row ? new Date(row.created_at).getTime() : null;
  }

  /** The custom character as the prompt and the app see it. */
  static customCharacter(personalityId: string | null, name: string | null): AssistantCharacter {
    const base = characterById(personalityId) ?? CHARACTERS[3];
    return {
      id: CUSTOM_ID,
      name: name ?? 'Your Assistant Manager',
      tagline: `Your own Assistant Manager, with ${base.name.replace('The ', 'the ')}'s style.`,
      style: base.style,
      voice: base.voice,
    };
  }

  /** The character from the photo, then each pose drawn from that character. */
  private async draw(photo: ImageData): Promise<Map<Pose, ImageData>> {
    const neutral = await this.llm.editImage(
      `Turn the person in this photo into a stylised football-manager character that clearly resembles them. ${STYLE} Calm, confident neutral expression, arms relaxed.`,
      photo,
    );
    const poses = new Map<Pose, ImageData>([['neutral', neutral]]);
    for (const [pose, description] of Object.entries(POSE_PROMPTS) as [Exclude<Pose, 'neutral'>, string][]) {
      poses.set(
        pose,
        await this.llm.editImage(
          'Keep this exact character - same face, hair, outfit, colours, lighting, background, canvas size and ' +
            `scale, feet in the same place. Change only the expression and pose to ${description}`,
          neutral,
        ),
      );
    }
    return poses;
  }
}
