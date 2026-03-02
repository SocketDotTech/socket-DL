# Chain-Specific Fee Collection

This document explains how to collect extra fees for specific chain paths (e.g., to/from Reya) using existing Socket DL contract parameters without any code changes.

## Overview

Socket DL allows collecting additional fees for specific chains by adjusting existing fee parameters. This is useful for:

- Charging premium fees for specific destination chains
- Collecting protocol fees for messages from specific source chains
- Implementing tiered pricing based on chain pairs

## Recommended Parameter: `transmissionFees` (with single-message packets)

If packets always contain exactly one message (`maxPacketLength = 1`), then transmission fees become per-message. That makes `transmissionFees` the cleanest mechanism for a flat surcharge with separate accounting.

### Why `transmissionFees` is Best (when `maxPacketLength = 1`)

| Criteria             | overhead           | verificationOverheadFees | transmissionFees                    |
| -------------------- | ------------------ | ------------------------ | ----------------------------------- |
| Per-message          | ✅ Yes             | ✅ Yes                   | ✅ Yes (with `maxPacketLength = 1`) |
| Per-destination      | ✅ Yes             | ✅ Yes                   | ✅ Yes                              |
| Easy to update       | ⚠️ Struct          | ⚠️ Two params            | ✅ Single value                     |
| Separate accounting  | ❌ Mixed with exec | ❌ Mixed with exec       | ✅ Separate bucket                  |
| Batch update support | ✅ SocketBatcher   | ❌ No batcher            | ❌ No batcher                       |

### How `transmissionFees` Works

**Storage** ([ExecutionManagerDF.sol:166](../contracts/ExecutionManagerDF.sol#L166)):

```solidity
mapping(address => mapping(uint32 => uint128)) public transmissionMinFees;
```

**Fee Calculation** ([ExecutionManagerDF.sol:350-358](../contracts/ExecutionManagerDF.sol#L350-L358)):

```solidity
transmissionFees =
    transmissionMinFees[transmitManager_][siblingChainSlug_] / maxPacketLength_;
```

With `maxPacketLength = 1`, `transmissionFees` equals the per-message surcharge.

---

## Implementation Guide

### Scenario: Charge $2 Extra for Messages TO and FROM Reya

#### 1. Messages TO Reya (Inbound to Reya)

On **each source chain's** `TransmitManager`, increase `transmissionFees` for Reya's chainSlug:

```solidity
// Example: On Ethereum's TransmitManager
TransmitManager.setTransmissionFees(
    nonce,
    REYA_CHAIN_SLUG,  // 1324967486
    currentTransmissionFees + surchargeInSourceNativeToken,
    signature
);
```

**Off-chain calculation**: `surcharge = $2 / sourceChainNativeTokenPriceUSD`

Example: If ETH = $2500, surcharge = 0.0008 ETH = 800000000000000 wei

#### 2. Messages FROM Reya (Outbound from Reya)

On **Reya's** `TransmitManager`, increase `transmissionFees` for ALL destination chains:

```solidity
// On Reya's TransmitManager
TransmitManager.setTransmissionFees(
    nonce,
    DESTINATION_CHAIN_SLUG,  // e.g., Ethereum = 1
    currentTransmissionFees + surchargeInReyaNativeToken,
    signature
);
```

This must be done for each destination chain that Reya can send to.

---

## Fee Flow Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                  TO DESTINATION CHAIN (surcharge)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Source Chain A ──┐                                             │
│  Source Chain B ──┼──► transmissionFees[DEST_SLUG] += $X ─► Dest│
│  Source Chain C ──┘    (set on each source chain)               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 FROM SOURCE CHAIN (surcharge)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│      transmissionFees[DEST_A] += $X  ──► Dest A                │
│  Source ─► transmissionFees[DEST_B] += $X  ──► Dest B           │
│      transmissionFees[DEST_C] += $X  ──► Dest C                │
│      (set on source chain's TransmitManager)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Batch Updates

There is no batch setter for `transmissionFees`. Updates must be sent per destination chain.

---

## Setter Function Details

### TransmitManager.setTransmissionFees()

**Location**: [contracts/TransmitManager.sol:94-126](../contracts/TransmitManager.sol#L94-L126)

```solidity
function setTransmissionFees(
    uint256 nonce_,
    uint32 siblingChainSlug_,
    uint128 transmissionFees_,
    bytes calldata signature_
) external
```

**Parameters**:

- `nonce_`: Incrementing nonce for the fee updater (replay protection)
- `siblingChainSlug_`: Destination chain identifier
- `transmissionFees_`: Fee per packet (equals per-message when `maxPacketLength = 1`)
- `signature_`: Signature from `FEES_UPDATER_ROLE` holder

**Signature Digest**:

```solidity
keccak256(abi.encode(
    FEES_UPDATE_SIG_IDENTIFIER,
    address(this),        // TransmitManager address
    chainSlug,            // Source chain slug
    siblingChainSlug_,    // Destination chain slug
    nonce_,
    transmissionFees_
))
```

---

## Where Surcharge Fees Go

The surcharge added via `transmissionFees` becomes part of **transmission fees**:

| Aspect     | Details                                                              |
| ---------- | -------------------------------------------------------------------- |
| Storage    | `totalExecutionAndTransmissionFees[chainSlug].totalTransmissionFees` |
| Withdrawal | `withdrawTransmissionFees(chainSlug, amount)`                        |
| Access     | Requires `WITHDRAW_ROLE`                                             |
| Recipient  | Managed by `TransmitManager.withdrawFees()`                          |

**Note**: Surcharge is combined with base transmission fees, but remains in a separate bucket from execution fees.

---

## Off-Chain Service Requirements

To maintain USD-denominated surcharges, the off-chain service needs to:

1. **Track token prices**: Native token price in USD for each chain
2. **Calculate surcharge**: `surchargeWei = $USD_AMOUNT / nativeTokenPriceUSD * 1e18`
3. **Sign updates**: Generate signature using `FEES_UPDATER_ROLE` private key
4. **Submit transactions**: Call `setTransmissionFees()` per destination chain
5. **Update frequency**: When token price moves >X% (e.g., 5%)

### Example Calculation

```javascript
const USD_SURCHARGE = 2; // $2
const ethPriceUSD = 2500;
const surchargeWei = BigInt((USD_SURCHARGE / ethPriceUSD) * 1e18);
// surchargeWei = 800000000000000n (0.0008 ETH)
```

---

## Alternative: Use verificationOverheadFees

If you want surcharge fees to go to the **switchboard** instead of executors:

```solidity
FastSwitchboard.setFees(
    nonce,
    DESTINATION_CHAIN_SLUG,
    switchboardFees,                              // unchanged
    verificationOverheadFees + surchargeAmount,   // add surcharge here
    signature
);
```

**Difference**:

- `transmissionFees` → goes to transmission fees bucket → withdrawn by transmit manager
- `verificationOverheadFees` → goes to switchboard fees bucket → withdrawn by switchboard

---

## Limitations

1. **No batch setter**: Must update each destination chain separately
2. **Multi-chain updates**: TO a chain requires updates on all source chains
3. **Price volatility**: USD value fluctuates with native token price
4. **All destinations**: FROM a chain applies surcharge to all destinations equally

---

## Summary

| Use Case                  | Where to Set      | Parameter                             | Function                |
| ------------------------- | ----------------- | ------------------------------------- | ----------------------- |
| Charge extra TO Chain X   | All source chains | `transmissionFees` for X's slug       | `setTransmissionFees()` |
| Charge extra FROM Chain Y | Chain Y           | `transmissionFees` for all dest slugs | `setTransmissionFees()` |
| Batch update              | Any chain         | N/A                                   | N/A                     |

**Key Files**:

- [contracts/ExecutionManagerDF.sol](../contracts/ExecutionManagerDF.sol) - Fee storage
- [contracts/TransmitManager.sol](../contracts/TransmitManager.sol) - Transmission fee setters
- [contracts/interfaces/ITransmitManager.sol](../contracts/interfaces/ITransmitManager.sol) - Interface definitions
