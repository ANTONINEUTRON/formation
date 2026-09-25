import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { User } from '../core/db-types.js';
import type { ProfileDto } from '../domain/dto.js';
import { shortAddress } from '../domain/sport.js';

@Injectable()
export class UsersService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async upsertByWallet(walletAddress: string): Promise<User> {
    const existing = await this.findByWallet(walletAddress);
    if (existing) return existing;
    return this.db
      .insertInto('users')
      .values({ wallet_address: walletAddress, username: shortAddress(walletAddress) })
      .returningAll()
      .executeTakeFirstOrThrow();
  }

  async findByWallet(walletAddress: string): Promise<User | undefined> {
    return this.db
      .selectFrom('users')
      .selectAll()
      .where('wallet_address', '=', walletAddress)
      .executeTakeFirst();
  }

  /** Resolves a duel opponent typed as a wallet address or username. */
  async findByHandle(handle: string): Promise<User> {
    const h = handle.trim();
    const user = await this.db
      .selectFrom('users')
      .selectAll()
      .where((eb) => eb.or([eb('wallet_address', '=', h), eb('username', '=', h)]))
      .executeTakeFirst();
    if (!user) {
      throw new NotFoundException(
        `No Formation player found for "${h}". They need to open the app first.`,
      );
    }
    return user;
  }

  async getMany(ids: string[]): Promise<Map<string, User>> {
    if (ids.length === 0) return new Map();
    const rows = await this.db
      .selectFrom('users')
      .selectAll()
      .where('id', 'in', [...new Set(ids)])
      .execute();
    return new Map(rows.map((r) => [r.id, r]));
  }

  /** The signed-in player's own profile. */
  async profile(userId: string): Promise<ProfileDto> {
    const user = await this.db
      .selectFrom('users')
      .select(['id', 'username', 'bio', 'email', 'wallet_address'])
      .where('id', '=', userId)
      .executeTakeFirst();
    if (!user) throw new NotFoundException('No such player');

    const [followers, following] = await Promise.all([
      this.countFollows('followee_id', userId),
      this.countFollows('follower_id', userId),
    ]);

    return {
      userId: user.id,
      username: user.username,
      bio: user.bio,
      email: user.email,
      walletAddress: user.wallet_address,
      followers,
      following,
    };
  }

  /**
   * Updates the player's public name and bio.
   *
   * Both are optional: sending only one leaves the other alone. An empty bio
   * clears it, which is different from not sending one at all.
   */
  async updateProfile(
    userId: string,
    input: { username?: string; bio?: string | null; email?: string | null },
  ): Promise<ProfileDto> {
    const update: { username?: string; bio?: string | null; email?: string | null } = {};

    if (input.username !== undefined) {
      update.username = normaliseUsername(input.username);
      const taken = await this.db
        .selectFrom('users')
        .select('id')
        .where((eb) => eb(eb.fn('lower', ['username']), '=', update.username!.toLowerCase()))
        .where('id', '!=', userId)
        .executeTakeFirst();
      if (taken) throw new ConflictException(`${update.username} is already taken`);
    }

    if (input.bio !== undefined) {
      const bio = input.bio === null ? null : input.bio.trim();
      if (bio !== null && bio.length > MAX_BIO) {
        throw new BadRequestException(`Your bio can be at most ${MAX_BIO} characters`);
      }
      update.bio = bio === '' ? null : bio;
    }

    if (input.email !== undefined) {
      const email = input.email === null ? null : input.email.trim().toLowerCase();
      if (email !== null && email !== '' && !EMAIL.test(email)) {
        throw new BadRequestException('That does not look like an email address');
      }
      update.email = email === '' ? null : email;

      if (update.email !== null) {
        const taken = await this.db
          .selectFrom('users')
          .select('id')
          .where('email', '=', update.email)
          .where('id', '!=', userId)
          .executeTakeFirst();
        if (taken) throw new ConflictException('That email is already in use');
      }
    }

    if (Object.keys(update).length > 0) {
      try {
        await this.db.updateTable('users').set(update).where('id', '=', userId).execute();
      } catch (e) {
        // The unique index is the backstop for a race between two callers.
        const message = String(e);
        if (message.includes('users_username')) {
          throw new ConflictException(`${update.username} is already taken`);
        }
        if (message.includes('users_email')) {
          throw new ConflictException('That email is already in use');
        }
        throw e;
      }
    }
    return this.profile(userId);
  }

  private async countFollows(column: 'follower_id' | 'followee_id', userId: string) {
    const row = await this.db
      .selectFrom('follows')
      .select((eb) => eb.fn.countAll<string>().as('count'))
      .where(column, '=', userId)
      .executeTakeFirst();
    return Number(row?.count ?? 0);
  }
}

/** Usernames are how players find and challenge each other, so keep them typeable. */
const MAX_BIO = 160;
const USERNAME = /^[A-Za-z0-9_]{3,20}$/;
/** Deliberately permissive: the point is to catch typos, not police addresses. */
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normaliseUsername(raw: string): string {
  const username = raw.trim();
  if (!USERNAME.test(username)) {
    throw new BadRequestException(
      'Usernames are 3-20 characters, using letters, numbers and underscores',
    );
  }
  return username;
}
