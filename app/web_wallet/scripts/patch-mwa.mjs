// Makes Mobile Wallet Adapter wait for Android's wallet chooser.
//
// When a phone has more than one MWA wallet (Phantom, Solflare, Seed Vault),
// opening "a wallet" shows Android's "open with" chooser. The library opens
// the association link, then gives the page 3 seconds to lose focus; a
// chooser waiting for the player's pick doesn't count, so it decides no
// wallet is installed and fails with ERROR_WALLET_NOT_FOUND. Meanwhile the
// chooser is still on screen, and picking a wallet would have worked.
//
// The patch lets that 3-second check carry on instead of failing. The next
// step already waits 30 seconds for the wallet to answer on its local
// socket, so a chooser has time, and a phone with no wallet at all still
// fails, after those 30 seconds, with ERROR_SESSION_TIMEOUT.
//
// Runs on install and before every build. It fails loudly if the library's
// code has changed, rather than shipping an unpatched bridge.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const lib = join(root, 'node_modules/@solana-mobile/mobile-wallet-adapter-protocol/lib');
const files = ['esm/index.browser.js', 'esm/index.js', 'cjs/index.browser.js', 'cjs/index.js'];

const MARKER = '/* formation: wait for the wallet chooser */';
const DETECTION = /const timeoutId = setTimeout\(\(\) => \{\s*cleanup\(\);\s*reject\(\);\s*\}, 3e3\);/;

for (const file of files) {
  const path = join(lib, file);
  const source = readFileSync(path, 'utf8');
  if (source.includes(MARKER)) continue;
  if (!DETECTION.test(source)) {
    throw new Error(`patch-mwa: the wallet detection in ${file} has changed; review scripts/patch-mwa.mjs`);
  }
  writeFileSync(
    path,
    source.replace(
      DETECTION,
      `const timeoutId = setTimeout(() => { ${MARKER} cleanup(); resolve(); }, 3e3);`,
    ),
  );
  console.log(`patch-mwa: patched ${file}`);
}
