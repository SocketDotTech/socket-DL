import { ChainSlug } from "../../src/enums/chainSlug";
import { providers } from "ethers";

const defaultType = 0;
const DEFAULT_GAS_PRICE_MULTIPLIER = 1.05;

type ChainOverride = {
  type?: number;
  gasLimit?: number;
  gasPrice?: number;
  gasPriceMultiplier?: number;
};

// Gas price calculation priority:
// 1. Use `gasPrice` if provided in chainOverrides
// 2. If not, calculate using `gasPriceMultiplier` from chainOverrides
// 3. If neither is provided, use DEFAULT_GAS_PRICE_MULTIPLIER
export const chainOverrides: {
  [chainSlug in ChainSlug]?: ChainOverride;
} = {
  [ChainSlug.ARBITRUM_SEPOLIA]: {
    type: 1,
    gasLimit: 50_000_000,
    gasPrice: 200_000_000,
  },
  [ChainSlug.BSC]: {
    gasLimit: 6_000_000,
  },
  [ChainSlug.MAINNET]: {
    gasLimit: 6_000_000,
    type: 2,
    gasPriceMultiplier: 1.25,
  },

  [ChainSlug.POLYGON_MAINNET]: {
    gasPriceMultiplier: 2,
    type: 2,
    gasLimit: 3_000_000,
  },
  [ChainSlug.ZKEVM]: {
    gasPriceMultiplier: 1.3,
  },
  [ChainSlug.BASE]: {
    gasPriceMultiplier: 2,
  },
  [ChainSlug.SEPOLIA]: {
    type: 1,
    gasLimit: 2_000_000,
    gasPriceMultiplier: 1.5,
  },
  [ChainSlug.AEVO_TESTNET]: {
    type: 1,
  },
  [ChainSlug.LYRA_TESTNET]: {
    type: 1,
  },
  [ChainSlug.MODE_TESTNET]: {
    type: 1,
    gasPrice: 100_000_000,
  },
  [ChainSlug.MODE]: {
    // type: 1,
    // gasLimit: 10_000_000,
    // gasPrice: 1_000_000,
  },

  [ChainSlug.SYNDR_SEPOLIA_L3]: {
    type: 1,
    gasLimit: 500_000_000,
    gasPrice: 1_000_000,
  },
  [ChainSlug.REYA_CRONOS]: {
    type: 1,
    gasPrice: 100_000_000,
  },
  [ChainSlug.REYA]: {
    type: 1,
    gasPrice: 100_000_000,
  },
  [ChainSlug.POLYNOMIAL_TESTNET]: {
    gasLimit: 4_000_000,
  },
  [ChainSlug.BOB]: {
    type: 1,
    gasLimit: 4_000_000,
    gasPrice: 100_000_000,
  },
  [ChainSlug.KINTO]: {
    // gasLimit: 4_000_000,
  },
  [ChainSlug.KINTO_DEVNET]: {
    gasLimit: 4_000_000,
  },
  [ChainSlug.MANTLE]: {
    // type: 1,
    // gasLimit: 10_000_000_000,
    // gasPrice: 30_000_000,
  },
  [ChainSlug.NEOX_TESTNET]: {
    type: 1,
    gasLimit: 1_000_000,
    gasPrice: 212_000_000_000,
  },
  [ChainSlug.GNOSIS]: {
    gasLimit: 15_000_000,
  },
  [ChainSlug.LINEA]: {
    gasLimit: 10_000_000,
  },
  [ChainSlug.AVALANCHE]: {
    gasLimit: 3_000_000,
    gasPriceMultiplier: 2,
  },
  [ChainSlug.SCROLL]: {
    gasLimit: 3_000_000,
    gasPriceMultiplier: 2,
  },
  [ChainSlug.PLUME]: {
    gasLimit: 5_000_000,
  },
  [ChainSlug.SEI]: {
    gasLimit: 5_000_000,
  },
  [ChainSlug.PLASMA]: {
    gasLimit: 5_000_000,
    gasPrice: 1_000_000_000,
    type: 2,
  },
  [ChainSlug.MONAD]: {
    gasLimit: 3_00_000,
  },
};

/**
 * Get transaction overrides for a specific chain
 *
 * Gas price calculation priority:
 * 1. Use `gasPrice` from chainOverrides if provided
 * 2. If not, calculate based on the current network gas price:
 *    a. Use `gasPriceMultiplier` from chainOverrides if provided
 *    b. If not, use DEFAULT_GAS_PRICE_MULTIPLIER
 *
 * For EIP-1559 transactions (type 2):
 * - Uses maxFeePerGas and maxPriorityFeePerGas instead of gasPrice
 * - Multiplier applies to maxFeePerGas
 * - maxPriorityFeePerGas = maxFeePerGas - baseFee
 *
 * @param chainSlug - The chain identifier
 * @param provider - The network provider
 * @returns An object with gasLimit, gasPrice/maxFeePerGas/maxPriorityFeePerGas, and transaction type
 */
export const getOverrides = async (
  chainSlug: ChainSlug,
  provider: providers.StaticJsonRpcProvider
) => {
  const overrides = chainOverrides[chainSlug] || {};
  const { gasLimit, type = defaultType } = overrides;

  if (type === 2) {
    // EIP-1559 transaction
    let maxFeePerGas = overrides.gasPrice;
    if (!maxFeePerGas) {
      const feeData = await provider.getFeeData();
      const baseGasPrice =
        feeData.maxFeePerGas || (await provider.getGasPrice());
      const multiplier =
        overrides.gasPriceMultiplier || DEFAULT_GAS_PRICE_MULTIPLIER;
      maxFeePerGas = baseGasPrice
        .mul(Math.round(multiplier * 100000))
        .div(100000)
        .toNumber();
    }

    // Get base fee to calculate maxPriorityFeePerGas
    const block = await provider.getBlock("latest");
    const baseFee = block.baseFeePerGas?.toNumber() || 0;
    const maxPriorityFeePerGas = Math.max(maxFeePerGas - baseFee, 0);
    return { gasLimit, maxFeePerGas, maxPriorityFeePerGas, type };
  } else {
    // Legacy transaction (type 0 or 1)
    let gasPrice = overrides.gasPrice;
    if (!gasPrice) {
      const baseGasPrice = await provider.getGasPrice();
      const multiplier =
        overrides.gasPriceMultiplier || DEFAULT_GAS_PRICE_MULTIPLIER;
      gasPrice = baseGasPrice
        .mul(Math.round(multiplier * 100000))
        .div(100000)
        .toNumber();
    }

    return { gasLimit, gasPrice, type };
  }
};
