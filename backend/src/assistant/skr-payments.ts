import { Inject, Injectable } from '@nestjs/common';
import {
  PublicKey,
  TransactionInstruction,
  TransactionMessage,
  VersionedTransaction,
} from '@solana/web3.js';
import type { ParsedInstruction, ParsedTransactionWithMeta, PartiallyDecodedInstruction } from '@solana/web3.js';
import { ChainService } from '../core/chain.service.js';

const ASSOCIATED_TOKEN_PROGRAM = new PublicKey('ATokenGPvbdGVxr1b2hvZbsiqW5xWSoWnSobmUFvc5Dg');
const MEMO_PROGRAM = new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');
const TRANSFER_CHECKED = 12;

/** Prefix on the memo, so a payment can't be mistaken for any other transfer. */
export const MEMO_PREFIX = 'formation:credits:';

export interface TransferRequest {
  payer: string;
  mint: string;
  decimals: number;
  treasury: string;
  amountRaw: bigint;
  memo: string;
}

/** What a confirmed transaction actually did, as far as a payment cares. */
export interface ObservedPayment {
  succeeded: boolean;
  /** Unix seconds, when the chain reports it. */
  blockTime: number | null;
  signers: string[];
  transfers: { mint: string; destination: string; authority: string; amountRaw: bigint }[];
  memos: string[];
}

/** Reaching the chain, behind an interface so tests never need an RPC node. */
export interface SkrPayments {
  /** An unsigned transaction (base64) the payer signs and sends themselves. */
  buildTransfer(request: TransferRequest): Promise<string>;
  /** Null until the transaction is visible at confirmed commitment. */
  observe(signature: string): Promise<ObservedPayment | null>;
}

export const SKR_PAYMENTS = Symbol('SKR_PAYMENTS');

export interface ExpectedPayment {
  payer: string;
  mint: string;
  treasury: string;
  amountRaw: bigint;
  memo: string;
  /** Unix seconds; a payment landing after this is too late for the quote. */
  notAfter: number;
}

/**
 * Why [observed] doesn't pay for [expected], or null if it does.
 *
 * Every condition is checked against what the chain recorded, never against
 * what the app says it sent: the right token, to the treasury, from the
 * Manager's own wallet, for at least the quoted amount, tagged with this
 * quote's memo, in time.
 */
export function paymentProblem(observed: ObservedPayment, expected: ExpectedPayment): string | null {
  if (!observed.succeeded) return 'The payment failed on-chain';
  if (!observed.signers.includes(expected.payer)) return 'The payment was not signed by your wallet';
  if (!observed.memos.some((m) => m.includes(expected.memo))) return 'That transaction is not for this purchase';
  const paid = observed.transfers
    .filter(
      (t) =>
        t.mint === expected.mint &&
        t.destination === expected.treasury &&
        t.authority === expected.payer,
    )
    .reduce((sum, t) => sum + t.amountRaw, 0n);
  if (paid === 0n) return 'No SKR reached Formation in that transaction';
  if (paid < expected.amountRaw) return 'The payment was less than the quoted amount';
  if (observed.blockTime !== null && observed.blockTime > expected.notAfter) {
    return 'The quote expired before the payment landed';
  }
  return null;
}

/** [amountRaw] SKR from the payer's associated account, as transferChecked. */
@Injectable()
export class SolanaSkrPayments implements SkrPayments {
  private readonly tokenPrograms = new Map<string, PublicKey>();

  constructor(@Inject(ChainService) private readonly chain: ChainService) {}

  async buildTransfer(request: TransferRequest): Promise<string> {
    const payer = new PublicKey(request.payer);
    const mint = new PublicKey(request.mint);
    const tokenProgram = await this.tokenProgramOf(mint);
    const [source] = PublicKey.findProgramAddressSync(
      [payer.toBuffer(), tokenProgram.toBuffer(), mint.toBuffer()],
      ASSOCIATED_TOKEN_PROGRAM,
    );

    const data = Buffer.alloc(10);
    data.writeUInt8(TRANSFER_CHECKED, 0);
    data.writeBigUInt64LE(request.amountRaw, 1);
    data.writeUInt8(request.decimals, 9);

    const transfer = new TransactionInstruction({
      programId: tokenProgram,
      keys: [
        { pubkey: source, isSigner: false, isWritable: true },
        { pubkey: mint, isSigner: false, isWritable: false },
        { pubkey: new PublicKey(request.treasury), isSigner: false, isWritable: true },
        { pubkey: payer, isSigner: true, isWritable: false },
      ],
      data,
    });
    const memo = new TransactionInstruction({
      programId: MEMO_PROGRAM,
      keys: [{ pubkey: payer, isSigner: true, isWritable: false }],
      data: Buffer.from(request.memo, 'utf8'),
    });

    const { blockhash } = await this.chain.connection.getLatestBlockhash('confirmed');
    const message = new TransactionMessage({
      payerKey: payer,
      recentBlockhash: blockhash,
      instructions: [transfer, memo],
    }).compileToV0Message();
    return Buffer.from(new VersionedTransaction(message).serialize()).toString('base64');
  }

  async observe(signature: string): Promise<ObservedPayment | null> {
    const tx = await this.chain.connection.getParsedTransaction(signature, {
      commitment: 'confirmed',
      maxSupportedTransactionVersion: 0,
    });
    return tx ? describe(tx) : null;
  }

  /** SKR could be a classic or a Token-2022 mint; the mint account says which. */
  private async tokenProgramOf(mint: PublicKey): Promise<PublicKey> {
    const cached = this.tokenPrograms.get(mint.toBase58());
    if (cached) return cached;
    const account = await this.chain.connection.getAccountInfo(mint);
    if (!account) throw new Error(`Mint ${mint.toBase58()} not found`);
    this.tokenPrograms.set(mint.toBase58(), account.owner);
    return account.owner;
  }
}

function describe(tx: ParsedTransactionWithMeta): ObservedPayment {
  const instructions: (ParsedInstruction | PartiallyDecodedInstruction)[] = [
    ...tx.transaction.message.instructions,
    ...(tx.meta?.innerInstructions ?? []).flatMap((inner) => inner.instructions),
  ];
  const transfers: ObservedPayment['transfers'] = [];
  const memos: string[] = [];

  for (const ix of instructions) {
    if (!('parsed' in ix)) continue;
    if (ix.program === 'spl-memo' && typeof ix.parsed === 'string') {
      memos.push(ix.parsed);
    } else if (
      (ix.program === 'spl-token' || ix.program === 'spl-token-2022') &&
      ix.parsed?.type === 'transferChecked'
    ) {
      const info = ix.parsed.info as {
        mint: string;
        destination: string;
        authority?: string;
        multisigAuthority?: string;
        tokenAmount: { amount: string };
      };
      transfers.push({
        mint: info.mint,
        destination: info.destination,
        authority: info.authority ?? info.multisigAuthority ?? '',
        amountRaw: BigInt(info.tokenAmount.amount),
      });
    }
  }

  return {
    // No meta means the node can't vouch for the outcome; treat it as failed.
    succeeded: tx.meta !== null && tx.meta.err === null,
    blockTime: tx.blockTime ?? null,
    signers: tx.transaction.message.accountKeys.filter((k) => k.signer).map((k) => k.pubkey.toBase58()),
    transfers,
    memos,
  };
}
