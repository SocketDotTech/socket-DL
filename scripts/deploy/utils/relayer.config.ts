import { RelayerConfig } from "./types";

export declare enum ChainId {
  GOERLI = 5,
  MUMBAI = 80001,
  ARBITRUM_TESTNET = 421613,
  OPTIMISM_TESTNET = 420,
  BSC_TESTNET = 97,
  MAINNET = 1,
  POLYGON = 137,
  ARBITRUM = 42161,
  OPTIMISM = 10,
  BSC = 56
}

export const getRelayerConfig = (
  chains: ChainId[]
): Map<ChainId, RelayerConfig> => {
  const relayerConfigs: Map<ChainId, RelayerConfig> = new Map<ChainId, RelayerConfig>();

  const rpcs = (process.env.RPC_LIST || "").split(",") as string[];
  const ozRelayerKeys = (process.env.OZ_RELAYER_KEY_LIST || "").split(
    ","
  ) as string[];
  const ozRelayerSecrets = (process.env.OZ_RELAYER_SECRET_LIST || "").split(
    ","
  ) as string[];

  if (
    rpcs.length !== chains.length ||
    ozRelayerKeys.length !== chains.length ||
    ozRelayerSecrets.length !== chains.length
  ) {
    throw new Error("Configs length don't match chain list length");
  }

  chains.map(async (chain, index) => {
    relayerConfigs.set(chain, {
      chainId: chain,
      rpc: rpcs[index],
      ozRelayerKey: ozRelayerKeys[index],
      ozRelayerSecret: ozRelayerSecrets[index],
    });
  })

  return relayerConfigs;
};
