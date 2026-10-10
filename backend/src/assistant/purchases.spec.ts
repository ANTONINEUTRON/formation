import { Keypair, PublicKey, VersionedTransaction } from '@solana/web3.js';
import type { ChainService } from '../core/chain.service.js';
import { parsePacks } from './packs.js';
import { MEMO_PREFIX, SolanaSkrPayments, paymentProblem } from './skr-payments.js';
import type { ExpectedPayment, ObservedPayment } from './skr-payments.js';

describe('parsePacks', () => {
  it('reads credits:usd pairs, smallest first', () => {
    expect(parsePacks('300:5, 50:1')).toEqual([
      { id: 'credits-50', credits: 50, usd: 1 },
      { id: 'credits-300', credits: 300, usd: 5 },
    ]);
    expect(parsePacks(undefined).length).toBe(3);
  });

  it('refuses a malformed or duplicated pack instead of mispricing it', () => {
    expect(() => parsePacks('50')).toThrow(/credits:usd/);
    expect(() => parsePacks('50:0')).toThrow();
    expect(() => parsePacks('50:1,50:2')).toThrow(/twice/);
  });
});

describe('paymentProblem', () => {
  const expected: ExpectedPayment = {
    payer: 'manager',
    mint: 'skr',
    treasury: 'treasury',
    amountRaw: 1_000n,
    memo: `${MEMO_PREFIX}quote-1`,
    notAfter: 2_000,
  };
  const good: ObservedPayment = {
    succeeded: true,
    blockTime: 1_900,
    signers: ['manager'],
    transfers: [{ mint: 'skr', destination: 'treasury', authority: 'manager', amountRaw: 1_000n }],
    memos: [`[${MEMO_PREFIX}quote-1]`],
  };

  it('accepts a transfer that matches the quote', () => {
    expect(paymentProblem(good, expected)).toBeNull();
    // Paying a little more than quoted is fine.
    expect(
      paymentProblem({ ...good, transfers: [{ ...good.transfers[0], amountRaw: 1_200n }] }, expected),
    ).toBeNull();
  });

  it.each<[string, Partial<ObservedPayment>, RegExp]>([
    ['it failed', { succeeded: false }, /failed/],
    ['someone else signed', { signers: ['stranger'] }, /not signed by your wallet/],
    ['the memo is for another quote', { memos: [`${MEMO_PREFIX}quote-2`] }, /not for this purchase/],
    ['it paid too little', { transfers: [{ ...good.transfers[0], amountRaw: 999n }] }, /less than/],
    ['it paid another mint', { transfers: [{ ...good.transfers[0], mint: 'usdc' }] }, /No SKR/],
    ['it paid someone else', { transfers: [{ ...good.transfers[0], destination: 'elsewhere' }] }, /No SKR/],
    ['it landed too late', { blockTime: 2_001 }, /expired/],
  ])('rejects a payment when %s', (_, change, message) => {
    expect(paymentProblem({ ...good, ...change }, expected)).toMatch(message);
  });
});

describe('SolanaSkrPayments.buildTransfer', () => {
  it('encodes a transferChecked from the payer to the treasury, plus the memo', async () => {
    const payer = Keypair.generate().publicKey;
    const mint = Keypair.generate().publicKey;
    const treasury = Keypair.generate().publicKey;
    const token2022 = new PublicKey('TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb');
    const chain = {
      connection: {
        getAccountInfo: async () => ({ owner: token2022 }),
        getLatestBlockhash: async () => ({ blockhash: Keypair.generate().publicKey.toBase58() }),
      },
    } as unknown as ChainService;

    const base64 = await new SolanaSkrPayments(chain).buildTransfer({
      payer: payer.toBase58(),
      mint: mint.toBase58(),
      decimals: 6,
      treasury: treasury.toBase58(),
      amountRaw: 1_234_567n,
      memo: `${MEMO_PREFIX}abc`,
    });

    const tx = VersionedTransaction.deserialize(Buffer.from(base64, 'base64'));
    const keys = tx.message.staticAccountKeys.map((k) => k.toBase58());
    const [transfer, memo] = tx.message.compiledInstructions;

    expect(keys[0]).toBe(payer.toBase58()); // fee payer and only signer
    expect(tx.message.header.numRequiredSignatures).toBe(1);
    expect(keys[transfer.programIdIndex]).toBe(token2022.toBase58());
    const data = Buffer.from(transfer.data);
    expect(data[0]).toBe(12); // TransferChecked
    expect(data.readBigUInt64LE(1)).toBe(1_234_567n);
    expect(data[9]).toBe(6);
    expect(keys[transfer.accountKeyIndexes[1]]).toBe(mint.toBase58());
    expect(keys[transfer.accountKeyIndexes[2]]).toBe(treasury.toBase58());
    expect(keys[transfer.accountKeyIndexes[3]]).toBe(payer.toBase58());
    // Source is the payer's associated account for this mint and program.
    const [ata] = PublicKey.findProgramAddressSync(
      [payer.toBuffer(), token2022.toBuffer(), mint.toBuffer()],
      new PublicKey('ATokenGPvbdGVxr1b2hvZbsiqW5xWSoWnSobmUFvc5Dg'),
    );
    expect(keys[transfer.accountKeyIndexes[0]]).toBe(ata.toBase58());
    expect(Buffer.from(memo.data).toString('utf8')).toBe(`${MEMO_PREFIX}abc`);
  });
});
