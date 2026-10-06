/**
 * Wallet bridge for the Formation Flutter web build.
 *
 * Flutter cannot talk to a browser extension directly, so this module wraps
 * the Wallet Standard and hangs a small, flat API off `window.formationWallet`
 * for `web_wallet_connector.dart` to call over `dart:js_interop`. Everything
 * crossing that boundary is a string, a boolean or a Uint8Array — no promises
 * of objects with methods, no classes.
 *
 * One registry covers both targets we care about: desktop extensions register
 * themselves (Phantom, Solflare, Backpack), and `registerMwa` adds a Mobile
 * Wallet Adapter entry when the page is open in Android Chrome, which is what
 * reaches Seed Vault on a Seeker.
 */
import { getWallets } from '@wallet-standard/app';
import {
  createDefaultAuthorizationCache,
  createDefaultChainSelector,
  createDefaultWalletNotFoundHandler,
  registerMwa,
} from '@solana-mobile/wallet-standard-mobile';
import bs58 from 'bs58';

import type { Wallet, WalletAccount } from '@wallet-standard/base';
import type {
  StandardConnectFeature,
  StandardDisconnectFeature,
} from '@wallet-standard/features';
import type {
  SolanaSignAndSendTransactionFeature,
  SolanaSignMessageFeature,
} from '@solana/wallet-standard-features';

const CHAIN = 'solana:mainnet';
const APP_IDENTITY = {
  name: 'Formation',
  uri: 'https://formation.titalabs.xyz',
  icon: 'favicon.png',
};

const StandardConnect = 'standard:connect';
const StandardDisconnect = 'standard:disconnect';
const SolanaSignMessage = 'solana:signMessage';
const SolanaSignAndSendTransaction = 'solana:signAndSendTransaction';

type Features = Partial<
  StandardConnectFeature &
    StandardDisconnectFeature &
    SolanaSignMessageFeature &
    SolanaSignAndSendTransactionFeature
>;

/** The wallet and account chosen by the player, for the life of the page. */
let active: { wallet: Wallet; account: WalletAccount } | null = null;

// Makes the MWA entry available on Android. The call itself checks for a
// secure context and local-association support, so it registers nothing on a
// desktop browser and the list below stays correct either way.
registerMwa({
  appIdentity: APP_IDENTITY,
  chains: [CHAIN],
  authorizationCache: createDefaultAuthorizationCache(),
  chainSelector: createDefaultChainSelector(),
  onWalletNotFound: createDefaultWalletNotFoundHandler(),
  // No `remoteHostAuthority`, so we never fall back to the hosted reflector:
  // this stays an on-device handoff, Android Chrome to Seed Vault.
});

const features = (wallet: Wallet) => wallet.features as Features;

/**
 * Waits for extensions to announce themselves, up to [REGISTER_GRACE_MS].
 *
 * Extensions register asynchronously, so reading the registry the moment
 * Flutter asks can come back empty on a cold load and show "no wallet found"
 * to someone who has three installed. Resolves as soon as one appears.
 */
const REGISTER_GRACE_MS = 750;

function waitForWallets(): Promise<void> {
  const wallets = getWallets();
  if (wallets.get().length > 0) return Promise.resolve();

  return new Promise((resolve) => {
    const done = () => {
      clearTimeout(timer);
      unsubscribe();
      resolve();
    };
    const timer = setTimeout(done, REGISTER_GRACE_MS);
    const unsubscribe = wallets.on('register', done);
  });
}

/** Wallets that can do everything Formation needs on mainnet. */
function usableWallets(): Wallet[] {
  return getWallets()
    .get()
    .filter((wallet) => {
      const f = features(wallet);
      return (
        wallet.chains.includes(CHAIN) &&
        f[StandardConnect] !== undefined &&
        f[SolanaSignMessage] !== undefined &&
        f[SolanaSignAndSendTransaction] !== undefined
      );
    });
}

/** Picks the account that can sign on mainnet, preferring the first one. */
function signingAccount(wallet: Wallet): WalletAccount | null {
  const usable = wallet.accounts.filter(
    (account) =>
      account.chains.includes(CHAIN) &&
      account.features.includes(SolanaSignAndSendTransaction),
  );
  // Some wallets report no per-account chains until after a signature; falling
  // back to the first account is better than refusing a working connection.
  return usable[0] ?? wallet.accounts[0] ?? null;
}

function requireActive() {
  if (!active) {
    throw new Error('No wallet is connected.');
  }
  return active;
}

/**
 * Lists the wallets the player can pick from.
 *
 * Called before anything is connected, so it reports what is installed rather
 * than what is authorized.
 */
async function list(): Promise<{ name: string; icon: string | null }[]> {
  await waitForWallets();
  return usableWallets().map((wallet) => ({
    name: wallet.name,
    icon: wallet.icon ?? null,
  }));
}

/**
 * Connects to `name`, or to the only installed wallet when `name` is null.
 *
 * With `silent` true this never shows a prompt: it asks each wallet to restore
 * an already-trusted session and gives up quietly, which is how a page reload
 * gets its account back without pestering the player. Returns null when
 * nothing connected, including when the player dismissed the prompt.
 */
async function connect(
  name: string | null,
  silent: boolean,
): Promise<{ address: string } | null> {
  await waitForWallets();

  const candidates = name
    ? usableWallets().filter((wallet) => wallet.name === name)
    : usableWallets();

  // A named wallet is an explicit choice, so a silent sweep is the only case
  // where trying several in turn makes sense.
  const toTry = silent || !name ? candidates : candidates.slice(0, 1);

  for (const wallet of toTry) {
    try {
      const account = silent
        ? await restore(wallet)
        : await authorize(wallet);
      if (!account) continue;

      active = { wallet, account };
      return { address: account.address };
    } catch (error) {
      // One locked or uninstalled wallet should not fail a whole sweep, but an
      // explicit single choice has to surface its reason to the player.
      if (!silent && toTry.length === 1) throw error;
    }
  }

  return null;
}

/** Prompts the player to authorize `wallet`. */
async function authorize(wallet: Wallet): Promise<WalletAccount | null> {
  const connectFeature = features(wallet)[StandardConnect];
  if (!connectFeature) return null;
  await connectFeature.connect();
  return signingAccount(wallet);
}

/**
 * Re-establishes a session without prompting, or gives up.
 *
 * Wallets that already trust this origin reconnect themselves on page load
 * and arrive with their accounts populated, which is the cheap path. Only
 * when that has not happened do we ask, and `silent` is what keeps that ask
 * from becoming a popup — a wallet that ignores the flag would prompt on page
 * load, so this is deliberately the last resort rather than the first move.
 */
async function restore(wallet: Wallet): Promise<WalletAccount | null> {
  const eager = signingAccount(wallet);
  if (eager) return eager;

  const connectFeature = features(wallet)[StandardConnect];
  if (!connectFeature) return null;
  await connectFeature.connect({ silent: true });
  return signingAccount(wallet);
}

async function disconnect(): Promise<void> {
  const current = active;
  active = null;
  if (!current) return;
  // Not every wallet offers this, and Flutter clears its own state regardless.
  await features(current.wallet)[StandardDisconnect]?.disconnect();
}

/** Returns the raw 64-byte ed25519 signature over `message`. */
async function signMessage(message: Uint8Array): Promise<Uint8Array> {
  const { wallet, account } = requireActive();
  const feature = features(wallet)[SolanaSignMessage];
  if (!feature) throw new Error(`${wallet.name} cannot sign messages.`);

  const [result] = await feature.signMessage({ account, message });
  if (!result) throw new Error('Sign-in was rejected in your wallet.');
  return result.signature;
}

/** Signs and submits a serialized transaction. Returns the base58 signature. */
async function signAndSendTransaction(transaction: Uint8Array): Promise<string> {
  const { wallet, account } = requireActive();
  const feature = features(wallet)[SolanaSignAndSendTransaction];
  if (!feature) throw new Error(`${wallet.name} cannot send transactions.`);

  const [result] = await feature.signAndSendTransaction({
    account,
    transaction,
    chain: CHAIN,
  });
  if (!result) throw new Error('Transaction was rejected in your wallet.');
  return bs58.encode(result.signature);
}

declare global {
  interface Window {
    formationWallet: {
      list: typeof list;
      connect: typeof connect;
      disconnect: typeof disconnect;
      signMessage: typeof signMessage;
      signAndSendTransaction: typeof signAndSendTransaction;
    };
  }
}

window.formationWallet = {
  list,
  connect,
  disconnect,
  signMessage,
  signAndSendTransaction,
};
