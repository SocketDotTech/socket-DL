import { ChainSlug } from "../../src/enums/chainSlug";
import { BigNumber, providers } from "ethers";

const defaultType = 0;

export const chainOverrides: {
  [chainSlug in ChainSlug]?: {
    type?: number;
    gasLimit?: number;
    gasPrice?: number;
  };
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
    // gasPrice: 5_000_000_000, // calculate in real time
  },

  [ChainSlug.POLYGON_MAINNET]: {
    // gasPrice: 50_000_000_000, // calculate in real time
  },
  [ChainSlug.SEPOLIA]: {
    type: 1,
    gasLimit: 2_000_000,
    // gasPrice: 50_000_000_000, // calculate in real time
  },
  [ChainSlug.AEVO_TESTNET]: {
    type: 2,
  },
  [ChainSlug.LYRA_TESTNET]: {
    type: 2,
  },
  [ChainSlug.MODE_TESTNET]: {
    type: 1,
    gasPrice: 100_000_000,
  },
  [ChainSlug.MODE]: {
    type: 1,
    gasLimit: 10_000_000,
    gasPrice: 1_000_000,
  },

  [ChainSlug.SYNDR_SEPOLIA_L3]: {
    type: 1,
    gasLimit: 500_000_000,
    gasPrice: 1_000_000,
  },
  [ChainSlug.HOOK]: {
    gasLimit: 7_000_000,
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
    type: 1,
    gasLimit: 100_000_000_000,
    gasPrice: 30_000_000,
  },
  [ChainSlug.NEOX_TESTNET]: {
    type: 1,
    gasLimit: 1_000_000,
    gasPrice: 212_000_000_000,
  },
};

export const getOverrides = async (
  chainSlug: ChainSlug,
  provider: providers.StaticJsonRpcProvider
) => {
  let overrides = chainOverrides[chainSlug];
  let gasPrice = overrides?.gasPrice;
  let gasLimit = overrides?.gasLimit;
  let type = overrides?.type;
  if (!gasPrice) gasPrice = (await getGasPrice(chainSlug, provider)).toNumber();
  if (type == undefined) type = defaultType;
  // if gas limit is undefined, ethers will calcuate it automatically. If want to override,
  // add in the overrides object. Dont set a default value
  return { gasLimit, gasPrice, type };
};

export const getGasPrice = async (
  chainSlug: ChainSlug,
  provider: providers.StaticJsonRpcProvider
): Promise<BigNumber> => {
  let gasPrice = await provider.getGasPrice();

  if (chainSlug === ChainSlug.POLYGON_MAINNET) {
    return gasPrice.mul(BigNumber.from(115)).div(BigNumber.from(100));
  }

  if ([ChainSlug.MAINNET].includes(chainSlug as ChainSlug)) {
    return gasPrice.mul(BigNumber.from(105)).div(BigNumber.from(100));
  }

  if ([ChainSlug.SEPOLIA].includes(chainSlug as ChainSlug)) {
    return gasPrice.mul(BigNumber.from(150)).div(BigNumber.from(100));
  }
  return gasPrice;
};
