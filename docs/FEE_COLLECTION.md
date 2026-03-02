# Socket DL Fee Collection Mechanism

This document explains how fees are collected, stored, and distributed across the Socket Data Layer protocol.

## Overview

When a user sends a cross-chain message via `Socket.outbound()`, they pay fees in the source chain's native token. These fees are split between three parties:

1. **Executor** - Executes the message on the destination chain
2. **Transmitter** - Relays packet roots between chains
3. **Switchboard** - Verifies/attests packets (e.g., watchers in FastSwitchboard)

All fees are collected and held in the **ExecutionManagerDF** contract, which acts as the central fee escrow.

## Fee Flow Diagram

```
User calls Socket.outbound() with msg.value
           │
           ▼
    SocketSrc._validateAndSendFees()
           │
           ├── Gets switchboardFees from Switchboard.getMinFees()
           │
           ▼
    ExecutionManagerDF.payAndCheckFees{value: msg.value}()
           │
           ├── Calculates minimum execution fees
           ├── Calculates transmission fees
           ├── Validates msg.value >= total minimum fees
           │
           ├── Stores executionFee in totalExecutionAndTransmissionFees[chainSlug].totalExecutionFees
           ├── Stores transmissionFees in totalExecutionAndTransmissionFees[chainSlug].totalTransmissionFees
           └── Stores switchboardFees in totalSwitchboardFees[switchboard][chainSlug]
```

## Fee Components

### 1. Execution Fees

Paid to executors for executing messages on the destination chain.

**Calculation** ([ExecutionManagerDF.sol:342-361](contracts/ExecutionManagerDF.sol#L342-L361)):

```
executionFee = gasLimit * perGasCost + payloadSize * perByteCost + overhead
```

The `ExecutionFeesParam` struct contains:

- `perGasCost` (uint80): Cost per unit of gas
- `perByteCost` (uint80): Cost per byte of payload (for rollup data costs)
- `overhead` (uint80): Fixed overhead cost

**Additional**: If the message includes native token value transfer (`executionParams_` has non-zero paramType), additional fees are calculated using `relativeNativeTokenPrice` to convert destination token value to source chain terms.

### 2. Transmission Fees

Paid to transmitters for relaying packet roots.

**Storage**: Set by `TransmitManager.setTransmissionFees()` which calls `ExecutionManager.setTransmissionMinFees()`.

**Key Detail**: Transmission fees are **per packet**, so they are divided by `maxPacketLength` to get per-message cost:

```solidity
transmissionFees = transmissionMinFees[transmitManager_][siblingChainSlug_] / maxPacketLength_;
```

### 3. Switchboard Fees

Paid to switchboards for verification/attestation services.

**Two components** ([SwitchboardBase.sol:53-56](contracts/switchboard/default-switchboards/SwitchboardBase.sol#L53-L56)):

```solidity
struct Fees {
  uint128 switchboardFees; // Paid to Switchboard per packet
  uint128 verificationOverheadFees; // Paid to executor per message
}
```

**FastSwitchboard special handling** ([FastSwitchboard.sol:171-178](contracts/switchboard/default-switchboards/FastSwitchboard.sol#L171-L178)):

- `switchboardFees` input is multiplied by `totalWatchers` before storage
- When watchers are added/removed, fees are proportionally adjusted

## Fee Collection (Source Chain)

### Entry Point: `SocketSrc.outbound()`

1. User calls `outbound()` with `msg.value` containing total fees
2. `_validateAndSendFees()` is called which:
   - Fetches `switchboardFees` and `verificationOverheadFees` from the switchboard
   - Calls `ExecutionManagerDF.payAndCheckFees()` forwarding full `msg.value`

### ExecutionManagerDF.payAndCheckFees()

[ExecutionManagerDF.sol:216-273](contracts/ExecutionManagerDF.sol#L216-L273)

```solidity
function payAndCheckFees(...) external payable returns (uint128 executionFee, uint128 transmissionFees) {
    // 1. Calculate transmission fees (per-message portion)
    transmissionFees = transmissionMinFees[transmitManager_][siblingChainSlug_] / maxPacketLength_;

    // 2. Calculate minimum execution fees
    uint128 minMsgExecutionFees = _getMinFees(minMsgGasLimit_, payloadSize_, executionParams_, siblingChainSlug_);
    uint128 minExecutionFees = minMsgExecutionFees + verificationOverheadFees_;

    // 3. Validate sufficient fees provided
    if (msgValue < transmissionFees + switchboardFees_ + minExecutionFees) revert InsufficientFees();

    // 4. Any extra fee beyond minimum goes to executor
    executionFee = msgValue - transmissionFees - switchboardFees_;

    // 5. Store fees in respective buckets
    totalExecutionAndTransmissionFees[siblingChainSlug_].totalExecutionFees += executionFee;
    totalExecutionAndTransmissionFees[siblingChainSlug_].totalTransmissionFees += transmissionFees;
    totalSwitchboardFees[switchboard_][siblingChainSlug_] += switchboardFees_;
}
```

**Important**: Any fees above the minimum are added to `executionFee`, incentivizing faster execution.

## Fee Withdrawal

All fees are held in ExecutionManagerDF until withdrawn.

### Execution Fees Withdrawal

[ExecutionManagerDF.sol:577-593](contracts/ExecutionManagerDF.sol#L577-L593)

```solidity
function withdrawExecutionFees(uint32 siblingChainSlug_, uint128 amount_, address withdrawTo_)
    external onlyRole(WITHDRAW_ROLE)
```

- Requires `WITHDRAW_ROLE`
- Transfers ETH directly to `withdrawTo_` address

### Transmission Fees Withdrawal

[ExecutionManagerDF.sol:623-638](contracts/ExecutionManagerDF.sol#L623-L638)

```solidity
function withdrawTransmissionFees(uint32 siblingChainSlug_, uint128 amount_) external
```

- Callable by anyone (pulls to TransmitManager)
- Gets TransmitManager address from Socket
- Calls `TransmitManager.receiveFees()` which only accepts from ExecutionManager
- TransmitManager holds fees until `withdrawFees()` is called by `WITHDRAW_ROLE`

### Switchboard Fees Withdrawal

[ExecutionManagerDF.sol:600-614](contracts/ExecutionManagerDF.sol#L600-L614)

```solidity
function withdrawSwitchboardFees(uint32 siblingChainSlug_, address switchboard_, uint128 amount_) external
```

- Callable by anyone (pulls to specified switchboard)
- Calls `Switchboard.receiveFees()` which only accepts from ExecutionManager
- Switchboard holds fees until `withdrawFees()` is called by `WITHDRAW_ROLE`

## Fee Parameter Updates (Setter Functions)

All fee parameters are updated via signed messages from addresses with `FEES_UPDATER_ROLE`. Each setter uses signature-based authentication with nonce tracking to prevent replay attacks.

### 1. Execution Fees

**Contract**: `ExecutionManagerDF`
**Function**: [setExecutionFees](contracts/ExecutionManagerDF.sol#L412-L441)

```solidity
function setExecutionFees(
    uint256 nonce_,
    uint32 siblingChainSlug_,
    ExecutionFeesParam calldata executionFees_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater (prevents replay)
- `siblingChainSlug_`: Destination chain identifier
- `executionFees_`: Struct containing `{perGasCost, perByteCost, overhead}`
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    FEES_UPDATE_SIG_IDENTIFIER,
    address(this),        // ExecutionManagerDF address
    chainSlug,            // Source chain slug
    siblingChainSlug_,    // Destination chain slug
    nonce_,
    executionFees_
))
```

**Storage Updated**: `executionFees[siblingChainSlug_] = executionFees_`

---

### 2. Transmission Fees

**Contract**: `TransmitManager`
**Function**: [setTransmissionFees](contracts/TransmitManager.sol#L94-L126)

```solidity
function setTransmissionFees(
    uint256 nonce_,
    uint32 dstChainSlug_,
    uint128 transmissionFees_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater
- `dstChainSlug_`: Destination chain identifier
- `transmissionFees_`: Fee per packet (not per message)
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    FEES_UPDATE_SIG_IDENTIFIER,
    address(this),        // TransmitManager address
    chainSlug,            // Source chain slug
    dstChainSlug_,
    nonce_,
    transmissionFees_
))
```

**Internal Call**: After validation, calls `ExecutionManager.setTransmissionMinFees(dstChainSlug_, transmissionFees_)`

**Storage Updated**: `transmissionMinFees[msg.sender][remoteChainSlug_] = fees_` (in ExecutionManagerDF)

---

### 3. Switchboard Fees

**Contract**: `FastSwitchboard` (or other switchboard implementations)
**Function**: [setFees](contracts/switchboard/default-switchboards/FastSwitchboard.sol#L143-L182)

```solidity
function setFees(
    uint256 nonce_,
    uint32 dstChainSlug_,
    uint128 switchboardFees_,
    uint128 verificationOverheadFees_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater
- `dstChainSlug_`: Destination chain identifier
- `switchboardFees_`: Fee per watcher (multiplied by `totalWatchers` before storage)
- `verificationOverheadFees_`: Additional fee paid to executor per message
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    FEES_UPDATE_SIG_IDENTIFIER,
    address(this),        // Switchboard address
    chainSlug,            // Source chain slug
    dstChainSlug_,
    nonce_,
    switchboardFees_,
    verificationOverheadFees_
))
```

**Storage Updated**:

```solidity
fees[dstChainSlug_] = Fees({
    switchboardFees: switchboardFees_ * totalWatchers[dstChainSlug_],
    verificationOverheadFees: verificationOverheadFees_
})
```

**Note**: For FastSwitchboard, `switchboardFees_` input is per-watcher and gets multiplied by `totalWatchers[dstChainSlug_]` before storage.

---

### 4. Relative Native Token Price

**Contract**: `ExecutionManagerDF`
**Function**: [setRelativeNativeTokenPrice](contracts/ExecutionManagerDF.sol#L451-L483)

```solidity
function setRelativeNativeTokenPrice(
    uint256 nonce_,
    uint32 siblingChainSlug_,
    uint256 relativeNativeTokenPrice_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater
- `siblingChainSlug_`: Destination chain identifier
- `relativeNativeTokenPrice_`: Price ratio = `(destTokenPriceUSD * 1e18) / srcTokenPriceUSD`
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER,
    address(this),
    chainSlug,
    siblingChainSlug_,
    nonce_,
    relativeNativeTokenPrice_
))
```

**Storage Updated**: `relativeNativeTokenPrice[siblingChainSlug_] = relativeNativeTokenPrice_`

**Usage**: Used when `executionParams_` contains a non-zero msg value to convert destination chain value to source chain terms.

---

### 5. Msg Value Min Threshold

**Contract**: `ExecutionManagerDF`
**Function**: [setMsgValueMinThreshold](contracts/ExecutionManagerDF.sol#L492-L520)

```solidity
function setMsgValueMinThreshold(
    uint256 nonce_,
    uint32 siblingChainSlug_,
    uint256 msgValueMinThreshold_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater
- `siblingChainSlug_`: Destination chain identifier
- `msgValueMinThreshold_`: Minimum native value that can be sent with a message
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER,
    address(this),
    chainSlug,
    siblingChainSlug_,
    nonce_,
    msgValueMinThreshold_
))
```

**Storage Updated**: `msgValueMinThreshold[siblingChainSlug_] = msgValueMinThreshold_`

---

### 6. Msg Value Max Threshold

**Contract**: `ExecutionManagerDF`
**Function**: [setMsgValueMaxThreshold](contracts/ExecutionManagerDF.sol#L529-L557)

```solidity
function setMsgValueMaxThreshold(
    uint256 nonce_,
    uint32 siblingChainSlug_,
    uint256 msgValueMaxThreshold_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater
- `siblingChainSlug_`: Destination chain identifier
- `msgValueMaxThreshold_`: Maximum native value that can be sent with a message
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER,
    address(this),
    chainSlug,
    siblingChainSlug_,
    nonce_,
    msgValueMaxThreshold_
))
```

**Storage Updated**: `msgValueMaxThreshold[siblingChainSlug_] = msgValueMaxThreshold_`

---

### Setter Functions Summary Table

| Fee Component        | Contract           | Function                        | Sig Identifier                                      | Storage Key                           |
| -------------------- | ------------------ | ------------------------------- | --------------------------------------------------- | ------------------------------------- |
| Execution Fees       | ExecutionManagerDF | `setExecutionFees()`            | `FEES_UPDATE_SIG_IDENTIFIER`                        | `executionFees[chainSlug]`            |
| Transmission Fees    | TransmitManager    | `setTransmissionFees()`         | `FEES_UPDATE_SIG_IDENTIFIER`                        | `transmissionMinFees[tm][chainSlug]`  |
| Switchboard Fees     | FastSwitchboard    | `setFees()`                     | `FEES_UPDATE_SIG_IDENTIFIER`                        | `fees[chainSlug]`                     |
| Relative Token Price | ExecutionManagerDF | `setRelativeNativeTokenPrice()` | `RELATIVE_NATIVE_TOKEN_PRICE_UPDATE_SIG_IDENTIFIER` | `relativeNativeTokenPrice[chainSlug]` |
| Min Value Threshold  | ExecutionManagerDF | `setMsgValueMinThreshold()`     | `MSG_VALUE_MIN_THRESHOLD_SIG_IDENTIFIER`            | `msgValueMinThreshold[chainSlug]`     |
| Max Value Threshold  | ExecutionManagerDF | `setMsgValueMaxThreshold()`     | `MSG_VALUE_MAX_THRESHOLD_SIG_IDENTIFIER`            | `msgValueMaxThreshold[chainSlug]`     |

### Nonce Management

Each fee updater address has its own nonce tracked in `nextNonce[feesUpdater]`. The nonce must match exactly for the transaction to succeed:

```solidity
if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
```

This prevents:

- Replay attacks (same signature can't be used twice)
- Out-of-order execution (signatures must be submitted in sequence)

## Fee Dependencies: Path vs Destination

Understanding which fees depend on the full path (source → destination) versus just the destination chain is critical for fee configuration and optimization.

### Dependency Summary Table

| Fee Component         | Dependency           | Key(s)                                               | Variability Factors                       |
| --------------------- | -------------------- | ---------------------------------------------------- | ----------------------------------------- |
| Execution Fees        | **Destination only** | `executionFees[dstChainSlug]`                        | Gas prices, L2 data costs, chain overhead |
| Transmission Fees     | **Path-dependent**   | `transmissionMinFees[transmitManager][dstChainSlug]` | Transmitter costs for specific route      |
| Switchboard Fees      | **Path-dependent**   | `fees[dstChainSlug]` (per switchboard instance)      | Number of watchers, verification method   |
| Verification Overhead | **Path-dependent**   | `fees[dstChainSlug].verificationOverheadFees`        | Switchboard-specific executor overhead    |
| Relative Token Price  | **Destination only** | `relativeNativeTokenPrice[dstChainSlug]`             | Token price fluctuations                  |
| Msg Value Thresholds  | **Destination only** | `msgValueMin/MaxThreshold[dstChainSlug]`             | Risk parameters, liquidity                |

### Detailed Analysis

#### 1. Execution Fees - Destination Only

```
Location: ExecutionManagerDF on SOURCE chain
Key: executionFees[destinationChainSlug]
```

**Why destination-only**: Execution fees represent the cost to execute on the destination chain. The source chain doesn't affect execution costs.

**Variability Factors**:

- `perGasCost`: Destination chain gas price (fluctuates with network congestion)
- `perByteCost`: L2 calldata costs (relevant for rollups like Arbitrum, Optimism)
- `overhead`: Fixed costs specific to destination chain (e.g., L1 data posting for rollups)

**Update Frequency**: Should be updated frequently via off-chain cron to track gas prices.

#### 2. Transmission Fees - Path Dependent

```
Location: ExecutionManagerDF on SOURCE chain
Key: transmissionMinFees[transmitManager][destinationChainSlug]
```

**Why path-dependent**: Different transmitters may operate different routes with varying costs. The mapping includes `transmitManager` address, allowing different fee structures per transmitter.

**Variability Factors**:

- Transmitter infrastructure costs for the specific route
- Gas costs on both source (sealing) and destination (proposing) chains
- Competition between transmitters

**Note**: In practice, most deployments use a single TransmitManager, so this effectively becomes destination-dependent.

#### 3. Switchboard Fees - Path Dependent (per Switchboard Instance)

```
Location: Switchboard contract on SOURCE chain
Key: fees[destinationChainSlug]
```

**Why path-dependent**: Each switchboard is a separate contract instance. A plug chooses which switchboard to use, and different switchboards have different fee structures.

**Variability Factors for FastSwitchboard**:

- **Number of watchers** (`totalWatchers[dstChainSlug]`): More watchers = higher fees
  ```solidity
  // Fee is per-watcher, multiplied by total watchers
  switchboardFees = switchboardFees_ * totalWatchers[dstChainSlug_]
  ```
- Watcher operational costs
- Attestation infrastructure

**Variability Factors for OptimisticSwitchboard**:

- Timeout duration (longer timeout = lower fees, slower finality)
- Dispute resolution costs

**Variability Factors for Native Switchboards** (Arbitrum, Optimism, Polygon):

- Native bridge fees
- L1↔L2 messaging costs

#### 4. Verification Overhead Fees - Path Dependent

```
Location: Switchboard contract on SOURCE chain
Key: fees[destinationChainSlug].verificationOverheadFees
```

**Why path-dependent**: This is an additional fee paid to executors for verification work, set by each switchboard independently.

**Variability Factors**:

- Proof verification gas costs on destination
- Switchboard-specific verification complexity

#### 5. Relative Native Token Price - Destination Only

```
Location: ExecutionManagerDF on SOURCE chain
Key: relativeNativeTokenPrice[destinationChainSlug]
```

**Formula**: `(destNativeTokenPriceUSD * 1e18) / srcNativeTokenPriceUSD`

**Why destination-only**: Converts value from source chain terms to destination chain terms. Only the destination chain's native token matters.

**Variability Factors**:

- Token price fluctuations (ETH, MATIC, BNB, etc.)
- Market volatility

**Update Frequency**: Should be updated very frequently (every few minutes) during high volatility.

#### 6. Msg Value Thresholds - Destination Only

```
Location: ExecutionManagerDF on SOURCE chain
Keys: msgValueMinThreshold[dstChainSlug], msgValueMaxThreshold[dstChainSlug]
```

**Why destination-only**: These are risk parameters for value transfers to the destination chain.

**Variability Factors**:

- Liquidity availability on destination
- Risk tolerance for the route
- Bridge capacity limits

### Path Selection Impact on Fees

When a plug connects to Socket, it specifies:

1. **Inbound Switchboard**: Affects fees for receiving messages
2. **Outbound Switchboard**: Affects fees for sending messages
3. **Capacitor Type**: Affects `maxPacketLength` which divides transmission and switchboard fees

```
Per-message cost = (transmissionFees + switchboardFees) / maxPacketLength + executionFees + verificationOverheadFees
```

**Implication**: Higher `maxPacketLength` (batching more messages) reduces per-message transmission and switchboard costs, but increases latency.

### Fee Configuration by Chain Type

| Chain Type            | perGasCost | perByteCost | overhead | Notes                 |
| --------------------- | ---------- | ----------- | -------- | --------------------- |
| L1 (Ethereum)         | High       | Low         | Low      | Gas-dominated         |
| Optimistic Rollup     | Medium     | High        | High     | L1 data posting costs |
| ZK Rollup             | Medium     | Medium      | High     | Proof costs           |
| Alt-L1 (BSC, Polygon) | Low        | Low         | Low      | Cheap execution       |

## Storage Mappings Summary

| Contract           | Mapping                                           | Purpose                                                      |
| ------------------ | ------------------------------------------------- | ------------------------------------------------------------ |
| ExecutionManagerDF | `totalExecutionAndTransmissionFees[chainSlug]`    | Stores execution + transmission fees per chain               |
| ExecutionManagerDF | `totalSwitchboardFees[switchboard][chainSlug]`    | Stores switchboard fees per switchboard per chain            |
| ExecutionManagerDF | `transmissionMinFees[transmitManager][chainSlug]` | Minimum transmission fee config                              |
| ExecutionManagerDF | `executionFees[chainSlug]`                        | Execution fee parameters (perGasCost, perByteCost, overhead) |
| ExecutionManagerDF | `relativeNativeTokenPrice[chainSlug]`             | Price ratio for cross-chain value transfers                  |
| SwitchboardBase    | `fees[dstChainSlug]`                              | Switchboard fee config per destination                       |

## Security Considerations

1. **Role-based access**: Withdrawal functions require specific roles (`WITHDRAW_ROLE`)
2. **Signature verification**: Fee updates require valid signatures from `FEES_UPDATER_ROLE` holders
3. **Nonce tracking**: Prevents replay attacks on fee update signatures
4. **Overflow protection**: Fees are capped at `uint128.max`
5. **Payload limits**: Max payload size of 5000 bytes prevents excessive fee calculation
