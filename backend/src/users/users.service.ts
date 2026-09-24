import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { User } from '../core/db-types.js';
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
}
