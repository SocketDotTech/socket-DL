import { type, gasLimit, gasMultiplier, gasPrice } from "./config";
import { ChainSlug } from "../../src";

export const overrides = {
  [ChainSlug.ARBITRUM]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.ARBITRUM_GOERLI]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.OPTIMISM]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.OPTIMISM_GOERLI]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.BSC]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.BSC_TESTNET]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.MAINNET]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.GOERLI]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.POLYGON_MAINNET]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
  [ChainSlug.POLYGON_MUMBAI]: {
    type,
    gasPrice,
    gasLimit,
    gasMultiplier,
  },
};
