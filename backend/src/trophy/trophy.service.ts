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
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { TrophyDto } from '../domain/dto.js';
import type { SportMode } from '../domain/sport.js';

const MEMO_PROGRAM_ID = new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');

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
    @Inject(DB) private readonly db: Db,
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
    const row = await this.db
      .insertInto('trophies')
      .values({
        user_id: input.userId,
        sport_mode: input.mode,
        type: 'duel_win',
        title: input.title,
        duel_id: input.duelId ?? null,
      })
      .returning('id')
      .executeTakeFirstOrThrow();
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
      await this.db
        .updateTable('trophies')
        .set({ tx_signature: signature })
        .where('id', '=', row.id)
        .execute();
    } catch (e) {
      // The trophy still counts; the memo can be retried later.
      this.logger.warn(`Trophy memo failed for ${row.id}: ${String(e)}`);
    }
  }

  async list(userId: string): Promise<TrophyDto[]> {
    const rows = await this.db
      .selectFrom('trophies')
      .select(['id', 'title', 'sport_mode', 'awarded_at', 'tx_signature'])
      .where('user_id', '=', userId)
      .orderBy('awarded_at', 'desc')
      .execute();
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      mode: r.sport_mode,
      awardedAt: new Date(r.awarded_at).toISOString(),
      txSignature: r.tx_signature,
    }));
  }
}
