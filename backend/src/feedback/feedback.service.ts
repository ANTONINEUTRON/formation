import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MAX_PHOTO_BYTES, PHOTO_TYPES } from '../assistant/avatars.js';
import type { UploadedPhoto } from '../assistant/avatars.js';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { FeedbackKind, FeedbackStatus } from '../core/db-types.js';
import type { AuthUser } from '../domain/dto.js';
import { requireString } from '../domain/validate.js';

const KINDS: FeedbackKind[] = ['bug', 'idea', 'other'];
const STATUSES: FeedbackStatus[] = ['new', 'read', 'done'];
const MIN_MESSAGE = 3;
const MAX_MESSAGE = 2000;
/** Submissions a Manager can send in an hour. */
export const FEEDBACK_PER_HOUR = 5;
const HOUR_MS = 60 * 60 * 1000;

export interface FeedbackItemDto {
  id: string;
  kind: FeedbackKind;
  rating: number | null;
  message: string;
  replyEmail: string | null;
  username: string;
  walletAddress: string;
  appVersion: string | null;
  platform: string | null;
  hasScreenshot: boolean;
  status: FeedbackStatus;
  createdAt: string;
}

/**
 * Feedback from Managers: a bug, an idea or anything else, with an optional
 * rating and screenshot. Kept in the database and read by the admin.
 */
@Injectable()
export class FeedbackService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async submit(
    user: AuthUser,
    body: Record<string, unknown>,
    screenshot: UploadedPhoto | undefined,
  ): Promise<{ id: string }> {
    const kind = KINDS.find((k) => k === body.kind);
    if (!kind) throw new BadRequestException('Pick bug, idea or other');

    let rating: number | null = null;
    if (body.rating !== undefined && body.rating !== null && body.rating !== '') {
      rating = Number(body.rating);
      if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
        throw new BadRequestException('A rating is 1 to 5');
      }
    }

    const message = requireString(body.message, 'message');
    if (message.length < MIN_MESSAGE) throw new BadRequestException('Tell us a little more');
    if (message.length > MAX_MESSAGE) {
      throw new BadRequestException(`Keep it under ${MAX_MESSAGE} characters`);
    }

    if (screenshot) {
      if (!PHOTO_TYPES.includes(screenshot.mimetype)) {
        throw new BadRequestException('Use a JPEG, PNG or WebP screenshot');
      }
      if (screenshot.size > MAX_PHOTO_BYTES) {
        throw new BadRequestException('That screenshot is too large (5 MB max)');
      }
    }

    const since = new Date(this.clock.now() - HOUR_MS);
    const recent = await this.db
      .selectFrom('feedback')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('user_id', '=', user.id)
      .where('created_at', '>', since)
      .executeTakeFirstOrThrow();
    if (Number(recent.n) >= FEEDBACK_PER_HOUR) {
      throw new HttpException("You've sent a lot of feedback this hour. Try again later.", HttpStatus.TOO_MANY_REQUESTS);
    }

    const profile = await this.db
      .selectFrom('users')
      .select('email')
      .where('id', '=', user.id)
      .executeTakeFirst();

    const row = await this.db
      .insertInto('feedback')
      .values({
        user_id: user.id,
        kind,
        rating,
        message,
        reply_email: profile?.email ?? null,
        app_version: optional(body.appVersion, 40),
        platform: optional(body.platform, 20),
        screenshot: screenshot?.buffer ?? null,
        screenshot_mime: screenshot?.mimetype ?? null,
        created_at: this.clock.date(),
      })
      .returning('id')
      .executeTakeFirstOrThrow();
    return { id: row.id };
  }

  /** Newest first, without the screenshots themselves. */
  async list(query: { status?: unknown; limit?: unknown }): Promise<FeedbackItemDto[]> {
    const status = STATUSES.find((s) => s === query.status);
    const limit = Math.min(200, Math.max(1, Number(query.limit) || 50));
    let q = this.db
      .selectFrom('feedback')
      .innerJoin('users', 'users.id', 'feedback.user_id')
      .select([
        'feedback.id as id',
        'feedback.kind as kind',
        'feedback.rating as rating',
        'feedback.message as message',
        'feedback.reply_email as reply_email',
        'users.username as username',
        'users.wallet_address as wallet_address',
        'feedback.app_version as app_version',
        'feedback.platform as platform',
        'feedback.status as status',
        'feedback.created_at as created_at',
      ])
      .select((eb) => eb('feedback.screenshot', 'is not', null).as('has_screenshot'))
      .orderBy('feedback.created_at', 'desc')
      .limit(limit);
    if (status) q = q.where('feedback.status', '=', status);
    const rows = await q.execute();
    return rows.map((r) => ({
      id: r.id,
      kind: r.kind,
      rating: r.rating,
      message: r.message,
      replyEmail: r.reply_email,
      username: r.username,
      walletAddress: r.wallet_address,
      appVersion: r.app_version,
      platform: r.platform,
      hasScreenshot: Boolean(r.has_screenshot),
      status: r.status,
      createdAt: new Date(r.created_at).toISOString(),
    }));
  }

  async screenshot(id: string): Promise<{ mime: string; data: Buffer }> {
    const row = await this.db
      .selectFrom('feedback')
      .select(['screenshot', 'screenshot_mime'])
      .where('id', '=', id)
      .executeTakeFirst()
      .catch(() => undefined); // a malformed uuid is just an unknown one
    if (!row?.screenshot || !row.screenshot_mime) throw new NotFoundException('No screenshot');
    return { mime: row.screenshot_mime, data: row.screenshot };
  }

  async setStatus(id: string, value: unknown): Promise<{ id: string; status: FeedbackStatus }> {
    const status = STATUSES.find((s) => s === value);
    if (!status) throw new BadRequestException('Status is new, read or done');
    const row = await this.db
      .updateTable('feedback')
      .set({ status })
      .where('id', '=', id)
      .returning('id')
      .executeTakeFirst()
      .catch(() => undefined);
    if (!row) throw new NotFoundException('Unknown feedback');
    return { id: row.id, status };
  }
}

/** A short optional text field, trimmed and capped; null when absent. */
function optional(value: unknown, max: number): string | null {
  return typeof value === 'string' && value.trim() ? value.trim().slice(0, max) : null;
}
