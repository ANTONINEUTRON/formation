import { Inject, Injectable, Logger } from '@nestjs/common';
import {
  Keypair,
  PublicKey,
  sendAndConfirmTransaction,
  Transaction,
  TransactionInstruction,
} from '@solana/web3.js';
import bs58 from 'bs58';
import { ChainService } from '../core/chain.service.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DbService, unwrap } from '../core/db.service.js';
import type { TrophyDto } from '../domain/dto.js';
import type { SportMode } from '../domain/sport.js';

const MEMO_PROGRAM_ID = new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');

interface TrophyRow {
  id: string;
  title: string;
  sport_mode: SportMode;
  awarded_at: string;
  tx_signature: string | null;
}

/**
 * Trophies are stored in the database and anchored on-chain with a memo
 * transaction from the Formation wallet, so each win has an explorer link.
 */
@Injectable()
export class TrophyService {
  private readonly logger = new Logger(TrophyService.name);
  private readonly signer?: Keypair;

  constructor(
    @Inject(CONFIG) config: AppConfig,
    private readonly db: DbService,
    private readonly chain: ChainService,
  ) {
    if (config.trophySecretKey) {
      this.signer = Keypair.fromSecretKey(bs58.decode(config.trophySecretKey));
    }
  }

  async award(input: {
    userId: string;
    wallet: string;
    mode: SportMode;
    title: string;
    duelId?: string;
  }): Promise<void> {
    const row: { id: string } = unwrap(
      await this.db.supabase
        .from('trophies')
        .insert({
          user_id: input.userId,
          sport_mode: input.mode,
          type: 'duel_win',
          title: input.title,
          duel_id: input.duelId ?? null,
        })
        .select('id')
        .single(),
    );
    if (!this.signer) return;

    try {
      const memo = `Formation trophy | ${input.title} | ${input.mode} | winner ${input.wallet} | ${row.id}`;
      const tx = new Transaction().add(
        new TransactionInstruction({
          programId: MEMO_PROGRAM_ID,
          keys: [],
          data: Buffer.from(memo, 'utf8'),
        }),
      );
      const signature = await sendAndConfirmTransaction(this.chain.connection, tx, [this.signer]);
      unwrap(
        await this.db.supabase.from('trophies').update({ tx_signature: signature }).eq('id', row.id),
      );
    } catch (e) {
      // The trophy still counts; the memo can be retried later.
      this.logger.warn(`Trophy memo failed for ${row.id}: ${String(e)}`);
    }
  }

  async list(userId: string): Promise<TrophyDto[]> {
    const rows: TrophyRow[] = unwrap(
      await this.db.supabase
        .from('trophies')
        .select('id, title, sport_mode, awarded_at, tx_signature')
        .eq('user_id', userId)
        .order('awarded_at', { ascending: false }),
    );
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      mode: r.sport_mode,
      awardedAt: r.awarded_at,
      txSignature: r.tx_signature,
    }));
  }
}
