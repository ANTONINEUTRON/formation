import { Injectable, NotFoundException } from '@nestjs/common';
import { DbService, unwrap } from '../core/db.service.js';
import { shortAddress } from '../domain/sport.js';

export interface UserRow {
  id: string;
  wallet_address: string;
  username: string;
  is_seed: boolean;
}

const COLUMNS = 'id, wallet_address, username, is_seed';

@Injectable()
export class UsersService {
  constructor(private readonly db: DbService) {}

  async upsertByWallet(walletAddress: string): Promise<UserRow> {
    const existing = await this.findByWallet(walletAddress);
    if (existing) return existing;
    return unwrap(
      await this.db.supabase
        .from('users')
        .insert({
          wallet_address: walletAddress,
          username: shortAddress(walletAddress),
        })
        .select(COLUMNS)
        .single(),
    );
  }

  async findByWallet(walletAddress: string): Promise<UserRow | null> {
    return unwrap(
      await this.db.supabase
        .from('users')
        .select(COLUMNS)
        .eq('wallet_address', walletAddress)
        .maybeSingle(),
    );
  }

  /** Resolves a duel opponent typed as a wallet address or username. */
  async findByHandle(handle: string): Promise<UserRow> {
    const h = handle.trim();
    const byWallet = await this.findByWallet(h);
    if (byWallet) return byWallet;
    const byName: UserRow | null = unwrap(
      await this.db.supabase
        .from('users')
        .select(COLUMNS)
        .eq('username', h)
        .maybeSingle(),
    );
    if (!byName) {
      throw new NotFoundException(
        `No Formation player found for "${h}". They need to open the app first.`,
      );
    }
    return byName;
  }

  async getMany(ids: string[]): Promise<Map<string, UserRow>> {
    if (ids.length === 0) return new Map();
    const rows: UserRow[] = unwrap(
      await this.db.supabase
        .from('users')
        .select(COLUMNS)
        .in('id', [...new Set(ids)]),
    );
    return new Map(rows.map((r) => [r.id, r]));
  }
}
