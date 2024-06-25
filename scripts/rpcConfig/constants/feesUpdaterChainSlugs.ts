import { batcherSupportedChainSlugs } from "./batcherSupportedChainSlug";
import {
  ChainSlug,
  DeploymentMode,
  MainnetIds,
  TestnetIds,
} from "../../../src";
import { mode } from "../../deploy/config/config";

export const feesUpdaterSupportedChainSlugs = (): ChainSlug[] => {
  if (mode === DeploymentMode.PROD) {
    const feesUpdaterSupportedChainSlugs = [];
    [...MainnetIds, ...TestnetIds].forEach((m) => {
      if (batcherSupportedChainSlugs.includes(m)) {
        feesUpdaterSupportedChainSlugs.push(m);
      }
    });

    return [
      ...feesUpdaterSupportedChainSlugs,
      // ChainSlug.POLYNOMIAL_TESTNET,
      // ChainSlug.KINTO_DEVNET,
      // ChainSlug.ARBITRUM_SEPOLIA,
    ];
  } else {
    return [
      ChainSlug.ARBITRUM_SEPOLIA,
      ChainSlug.OPTIMISM_SEPOLIA,
      ChainSlug.SEPOLIA,
    ];
  }
};
