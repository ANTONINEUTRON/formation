# Symbians — Solana Programs

> Anchor-based Solana smart contracts for on-chain ownership, minting, and transactions.

---

## Responsibilities

- **Space NFT Minting** — Allows users to claim a parcel on the 2D grid and mint it as a Metaplex NFT. Each NFT stores the space coordinates `(x, y)` and owner wallet.
- **Space Marketplace** — On-chain listing and purchasing of space NFTs. Seller sets a SOL price; buyer transfers SOL and receives the NFT atomically.
- **Wager Escrow** — Manages SOL escrow for game wagers. When agents enter a game room with a stake, SOL is locked in a PDA. On game completion, the winner's wallet receives the pot (minus optional platform fee).
- **Space Registry** — On-chain record of all minted spaces, their coordinates, and current owners. Prevents double-claiming of parcels.

## Key Structure

```
programs/
├── symbians/
│   └── src/
│       ├── lib.rs                # Program entry point
│       ├── instructions/
│       │   ├── mint_space.rs     # Claim parcel + mint Metaplex NFT
│       │   ├── list_space.rs     # List space for sale
│       │   ├── buy_space.rs      # Purchase listed space
│       │   ├── create_escrow.rs  # Lock SOL for a game wager
│       │   └── settle_escrow.rs  # Distribute winnings after game ends
│       ├── state/
│       │   ├── space.rs          # Space account (coords, owner, metadata URI)
│       │   ├── listing.rs        # Marketplace listing account
│       │   └── escrow.rs         # Wager escrow account
│       └── errors.rs             # Custom error codes
├── tests/
│   └── symbians.ts               # Anchor test suite (TypeScript)
├── Anchor.toml
└── Cargo.toml
```

## Tech

- **Framework:** Anchor
- **Language:** Rust
- **NFT Standard:** Metaplex Token Metadata
- **Network:** Solana Devnet (development) → Mainnet-Beta (production)
- **Testing:** Anchor test runner + `@coral-xyz/anchor` TypeScript client

## Key Accounts (PDAs)

| Account | Seeds | Purpose |
|---|---|---|
| `Space` | `["space", x, y]` | Stores parcel ownership and metadata |
| `Listing` | `["listing", space_pubkey]` | Active marketplace listing with price |
| `Escrow` | `["escrow", room_id]` | Locked SOL for an active game wager |

## Getting Started

```bash
# Install Anchor CLI if not already installed
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest && avm use latest

# Build and test
anchor build
anchor test
```
