# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Socket DL (Data Layer) is a protocol for generic message passing between blockchains. It enables dapps ("plugs") to send and receive cross-chain messages with configurable security/speed tradeoffs. The protocol is deployed across 70+ EVM chains.

## Build and Test Commands

```bash
# Install dependencies
forge install && yarn install

# Compile contracts
forge build          # or: yarn compile

# Run tests (formats changed files first)
yarn test            # runs: prettier + forge test

# Run specific test file
forge test --match-path test/socket/SocketSrc.t.sol

# Run specific test function
forge test --match-test testOutbound

# Lint/format
yarn lint

# Export ABIs
yarn abi             # or: hardhat export-abi

# Build TypeScript package
yarn build           # exports ABIs + compiles TS
```

## Deployment

Deployment uses Hardhat. Three modes exist: `dev`, `surge`, `prod` (set via `DEPLOYMENT_MODE` env var).

```bash
# Full deployment flow
bash deploy.sh

# Individual steps
npx hardhat run scripts/deploy/deploy.ts      # Deploy contracts
npx hardhat run scripts/deploy/verify.ts      # Verify on explorers
```

Key deployment files:

- [scripts/deploy/config/config.ts](scripts/deploy/config/config.ts) - Chain configuration, role addresses
- [deployments/{mode}\_addresses.json](deployments/) - Deployed contract addresses
- `.env` - Private keys, RPC URLs, API keys (see `.env.example`)

## Architecture

### Core Message Flow

1. **Source Chain**: Plug calls `Socket.outbound()` → message packed into Capacitor → Transmitter seals packet
2. **Destination Chain**: Transmitter proposes packet root → Switchboard verifies → Executor calls `Socket.execute()` → Plug receives `inbound()`

### Contract Hierarchy

```
Socket (main entry point)
├── SocketSrc - Outbound message handling, packet sealing
├── SocketDst - Inbound execution, packet verification
├── SocketConfig - Plug configuration, switchboard registration
└── SocketBase - Shared state (hasher, capacitorFactory, managers)
```

### Key Contracts

- **Socket** ([contracts/socket/Socket.sol](contracts/socket/Socket.sol)): Core contract combining source and destination logic
- **Capacitors** ([contracts/capacitors/](contracts/capacitors/)): Accumulate messages into packets (SingleCapacitor for 1:1, HashChainCapacitor for batching)
- **Switchboards** ([contracts/switchboard/](contracts/switchboard/)): Verify packets. Types:
  - `FastSwitchboard` - Watcher-based attestation
  - `OptimisticSwitchboard` - Timeout-based
  - Native bridges (Arbitrum, Optimism, Polygon) - Use L1↔L2 messaging
- **ExecutionManager** ([contracts/ExecutionManager.sol](contracts/ExecutionManager.sol)): Fee handling, executor verification
- **TransmitManager** ([contracts/TransmitManager.sol](contracts/TransmitManager.sol)): Transmitter signature verification

### Integration Pattern

Dapps implement the `IPlug` interface:

```solidity
interface IPlug {
  function inbound(
    uint32 srcChainSlug_,
    bytes calldata payload_
  ) external payable;
}
```

Plugs connect to Socket specifying: sibling plug address, switchboard for inbound/outbound, and capacitor type.

### TypeScript SDK (`src/`)

Published as `@socket.tech/dl-core`. Exports:

- Chain enums (`ChainSlug`, `ChainId`)
- Contract addresses by deployment mode
- Transmission utilities

## Code Style (Solidity)

- Private/internal variables and functions: underscore prefix (`_foo`, `_bar()`)
- Function parameters: underscore postfix (`param_`)
- Contract instances: double underscore postfix (`contract__`)
- Events: past tense, emitted immediately after state change
- All state variables should be private/internal with explicit getters where needed

## Environment Variables

Required in `.env`:

- `DEPLOYMENT_MODE` - dev/surge/prod
- `SOCKET_SIGNER_KEY` - Deployer private key
- `SOCKET_OWNER_ADDRESS` - Contract owner
- Chain-specific RPCs and explorer API keys
