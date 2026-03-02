# S3 Configuration for Chain-Specific Surcharges

This document explains how to configure chain-specific USD surcharges in S3 to enable additional fees for transmission between specific chains.

## Overview

The fees-updater service reads a surcharge configuration from S3 at startup. This configuration allows you to add USD-denominated surcharges to transmission fees for specific chains. The surcharges are automatically converted to native token amounts based on real-time token prices.

## S3 Configuration Location

The configuration is stored in AWS Secrets Manager and loaded via S3:

- **Path**: `/backend/{stage}/dl/fees-updater`
- **Stage**: `dev`, `prod`, or `surge`

## Configuration Format

Add a `chainSurchargeUsdBySlug` field to your S3 configuration JSON:

```json
{
  "chainSurchargeUsdBySlug": {
    "1324967486": 2,
    "1": 1.5,
    "42161": 1,
    "10": 0.5
  }
}
```

### Field Specification

- **Field name**: `chainSurchargeUsdBySlug`
- **Type**: Object/dictionary
- **Keys**: Chain slug as string (e.g., `"1"` for Ethereum, `"1324967486"` for Reya)
- **Values**: USD surcharge amount as number (float or integer)

### Important Notes

1. **Keys must be strings**: JSON keys are always strings, but they represent numeric chain slugs
2. **Values are in USD**: Not micro-USD, not wei - just regular USD amounts (e.g., `2` = $2.00)
3. **Optional field**: If omitted, no surcharges are applied
4. **Optional chains**: Chains not in the map have zero surcharge

## Chain Slug Reference

Common chain slugs:

| Chain            | Slug (as string) |
| ---------------- | ---------------- |
| Ethereum Mainnet | `"1"`            |
| Arbitrum One     | `"42161"`        |
| Optimism         | `"10"`           |
| Polygon          | `"137"`          |
| Base             | `"8453"`         |
| BSC              | `"56"`           |
| Reya             | `"1324967486"`   |

> **Tip**: Find all supported chain slugs in the `@socket.tech/dl-core` package or your existing S3 config under the `chains` field.

## How Surcharges are Applied

### Additive Logic

For each transmission from source chain to destination chain:

```
Total Surcharge (USD) = surcharge[sourceChainSlug] + surcharge[destinationChainSlug]
```

### Examples

#### Example 1: TO Reya surcharge only

```json
{
  "chainSurchargeUsdBySlug": {
    "1324967486": 2
  }
}
```

- **Ethereum → Reya**: $2 surcharge (from Reya's entry)
- **Arbitrum → Reya**: $2 surcharge (from Reya's entry)
- **Reya → Ethereum**: $2 surcharge (from Reya's entry)
- **Ethereum → Arbitrum**: $0 surcharge (neither chain in config)

#### Example 2: FROM and TO surcharges

```json
{
  "chainSurchargeUsdBySlug": {
    "1324967486": 2,
    "1": 1.5
  }
}
```

- **Ethereum → Reya**: $3.50 surcharge ($1.50 from Ethereum + $2 from Reya)
- **Reya → Ethereum**: $3.50 surcharge ($2 from Reya + $1.50 from Ethereum)
- **Ethereum → Arbitrum**: $1.50 surcharge ($1.50 from Ethereum)
- **Arbitrum → Reya**: $2 surcharge ($2 from Reya)
- **Arbitrum → Optimism**: $0 surcharge (neither chain in config)

#### Example 3: Multiple chain surcharges

```json
{
  "chainSurchargeUsdBySlug": {
    "1324967486": 2,
    "1": 1.5,
    "42161": 1,
    "10": 0.5
  }
}
```

- **Ethereum → Reya**: $3.50 ($1.50 + $2)
- **Arbitrum → Optimism**: $1.50 ($1 + $0.50)
- **Reya → Arbitrum**: $3 ($2 + $1)

## USD to Native Token Conversion

The service automatically converts USD surcharges to native token amounts:

1. **Token prices**: Fetched from CoinGecko and stored in `usdPriceMap` (micro-USD integers)
2. **Conversion formula**:
   ```
   surchargeWei = (totalSurchargeUSD * 1e6) * 1e18 / srcNativeTokenPriceMicroUSD
   ```
3. **Updates**: Surcharges are recalculated on every fee update cycle using current prices

### Conversion Example

If ETH = $2,500 and you configure a $2 surcharge:

```
surchargeWei = (2 * 1,000,000) * 1e18 / 2,500,000,000
             = 2,000,000 * 1e18 / 2,500,000,000
             = 800,000,000,000,000 wei
             = 0.0008 ETH
```

## Deployment Steps

### 1. Update S3 Configuration

Add the `chainSurchargeUsdBySlug` field to your S3 config:

```bash
# Example for dev stage
aws secretsmanager update-secret \
  --secret-id /backend/dev/dl/fees-updater \
  --secret-string '{
    "chainSurchargeUsdBySlug": {
      "1324967486": 2,
      "1": 1.5
    },
    ... (other existing config fields)
  }'
```

### 2. Deploy or Restart Service

The configuration is loaded at service initialization:

```bash
# Deploy to reload config
yarn deploy:dev

# OR restart existing deployment
# (if using serverless offline or similar)
```

### 3. Verify Configuration

Check logs for successful config load:

```
[INFO] Loaded chain surcharge config: 2 chains with surcharges
```

### 4. Monitor Surcharge Application

Look for surcharge logs in transmission fee updates:

```
[INFO] transmitFees-surcharge: Ethereum-Reya
       surcharge native: 800000000000000
```

## Testing Configuration

### Local Testing

1. Update your local S3 config file
2. Start serverless offline:
   ```bash
   yarn start:dev
   ```
3. Invoke the transmit fees updater:
   ```bash
   npx sls invoke local -s dev -f transmitFeesUpdater
   ```
4. Check logs for surcharge application

### API Verification

Query the calculated fees API to verify surcharges are included:

```bash
curl https://your-api-endpoint/current-fees
```

The `transmitFees` values should reflect the added surcharge.

## Troubleshooting

### Surcharges Not Applied

**Problem**: Logs show zero surcharge when expected

**Possible causes**:

1. Chain slug mismatch (verify exact chain slug in S3 config)
2. Token price missing in `usdPriceMap`
3. Configuration not reloaded (restart service)

**Solution**: Check logs for:

```
[INFO] Loaded chain surcharge config: X chains with surcharges
```

### Incorrect Surcharge Amount

**Problem**: Applied surcharge doesn't match expected USD value

**Possible causes**:

1. Token price changed between config and execution
2. Wrong token price in `usdPriceMap`

**Solution**:

- Surcharges are recalculated each cycle based on current prices
- Verify token price: check CoinGecko API response in logs

### Configuration Syntax Error

**Problem**: Service fails to start after config update

**Possible causes**:

1. Invalid JSON syntax
2. Non-numeric chain slugs
3. Non-numeric surcharge values

**Solution**:

- Validate JSON syntax before updating S3
- Ensure chain slugs are string representations of numbers
- Ensure surcharge values are numbers, not strings

## Example Complete Configuration

```json
{
  "chainSurchargeUsdBySlug": {
    "1324967486": 2,
    "1": 1.5
  },
  "addresses": {
    "TransmitManager": "0x...",
    "ExecutionManager": "0x..."
  },
  "chains": {
    "1": {
      "rpc": "https://...",
      "nativeToken": "ETH"
    },
    "1324967486": {
      "rpc": "https://...",
      "nativeToken": "REYA"
    }
  },
  "DELTA_THRESHOLD": 30,
  "FEE_BUMP_PERCENTAGE": 10
}
```

## Related Documentation

- [CHAIN_SPECIFIC_FEES.md](./CHAIN_SPECIFIC_FEES.md) - Technical implementation details
- [README.md](../README.md) - General project documentation
- S3 config schema (to be created)

## Support

If you encounter issues:

1. Check service logs for error messages
2. Verify S3 configuration syntax
3. Ensure chain slugs match exactly
4. Confirm token prices are available in `usdPriceMap`
