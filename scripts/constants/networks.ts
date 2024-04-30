import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import { ChainSlug, hardhatChainNameToSlug } from "../../src";
import { HardhatChainName } from "@socket.tech/dl-core";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

export const chainSlugReverseMap = createReverseEnumMap(ChainSlug);
function createReverseEnumMap(enumObj: any) {
  const reverseMap = new Map<string, string>();
  for (const [key, value] of Object.entries(enumObj)) {
    reverseMap.set(String(value) as unknown as string, String(key));
  }
  return reverseMap;
}

export const rpcKeys = (chainSlug: ChainSlug) => {
  const chainName = chainSlugReverseMap.get(String(chainSlug));
  return `${chainName.toUpperCase()}_RPC`;
};

export function getJsonRpcUrl(chain: ChainSlug): string {
  let chainRpcKey = rpcKeys(chain);
  if (!chainRpcKey) throw Error(`Chain ${chain} not found in rpcKey`);
  let rpc = process.env[chainRpcKey];
  if (!rpc) {
    throw new Error(
      `RPC not configured for chain ${chain}. Missing env variable : ${rpcKeys(
        chain
      )}`
    );
  }
  return rpc;
}

const getProviderFromChainSlug = (chainSlug: ChainSlug) => {
  const jsonRpcUrl = getJsonRpcUrl(chainSlug);
  return new ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};

export const getProviderFromChainName = (chainName: HardhatChainName) => {
  return getProviderFromChainSlug(hardhatChainNameToSlug[chainName]);
};
