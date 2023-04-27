import { RelayerConfig, relayTxSpeed } from "./types";
import { Signer } from "ethers";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
import { StaticJsonRpcProvider } from "@ethersproject/providers";
import { DefenderRelaySigner } from "defender-relay-client/lib/ethers";
import { getJsonRpcUrl } from "../../constants";
import { networkToChainSlug } from "../../../src";
const dotenvConfigPath: string =
  process.env.DOTENV_CONFIG_PATH || "../../../.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

export const loadRelayerConfigs = (): Map<number, RelayerConfig> => {
  const relayerConfigs: Map<number, RelayerConfig> = new Map<
    number,
    RelayerConfig
  >();

  const rpcs = (process.env.RPC_LIST || "").split(",") as string[];
  const ozRelayerKeys = (process.env.OZ_RELAYER_KEY_LIST || "").split(
    ","
  ) as string[];
  const ozRelayerSecrets = (process.env.OZ_RELAYER_SECRET_LIST || "").split(
    ","
  ) as string[];

  const chains: string[] = (process.env.CHAIN_LIST || "").split(
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
    relayerConfigs.set(parseInt(chain), {
      chainId: parseInt(chain),
      rpc: rpcs[index],
      ozRelayerKey: ozRelayerKeys[index],
      ozRelayerSecret: ozRelayerSecrets[index],
    });
  });

  return relayerConfigs;
};

const relayerConfigs: Map<number, RelayerConfig> = loadRelayerConfigs();

export const getRpcProvider = (chainSlug: number) => {
  return new StaticJsonRpcProvider(
    getJsonRpcUrl(networkToChainSlug[chainSlug])
  );
};

export const getSigner = (chainSlug: number) => {
  //get RelayerConfig for the chainId
  const relayerConfig: RelayerConfig = relayerConfigs.get(
    chainSlug
  ) as RelayerConfig;

  const provider: StaticJsonRpcProvider = new StaticJsonRpcProvider(
    relayerConfig.rpc
  );

  const signer: Signer = new DefenderRelaySigner(
    {
      apiKey: relayerConfig.ozRelayerKey,
      apiSecret: relayerConfig.ozRelayerSecret,
    },
    provider,
    { speed: relayTxSpeed }
  );

  return signer;
};
