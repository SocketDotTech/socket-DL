import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import {
  ChainId,
  ChainSlug,
  ChainSlugToId,
  hardhatChainNameToSlug,
  HardhatChainName,
  chainSlugToHardhatChainName,
  zkStackChain,
} from "../../src";

import "@matterlabs/hardhat-zksync-node/dist/type-extensions";
import {
  Wallet as zkWallet,
  Provider,
} from "@matterlabs/hardhat-zksync/node_modules/zksync-ethers";

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

export const chainIdToSlug = (chainId: ChainId) => {
  const chainName = chainSlugReverseMap.get(chainId.toString());
  return ChainSlug[chainName as keyof typeof ChainSlug];
};

export const rpcKeys = (chainSlug: ChainSlug) => {
  const chainName = chainSlugToHardhatChainName[chainSlug].toString();
  return `${chainName.toUpperCase()}_RPC`;
};

export function getJsonRpcUrl(chain: ChainSlug): string {
  let chainRpcKey = rpcKeys(chain);
  if (!chainRpcKey) throw Error(`Chain ${chain} not found in rpcKey`);
  let rpc = process.env[chainRpcKey];
  if (!rpc) {
    throw new Error(
      `RPC not configured for chain ${chain}. Missing env variable : ${chainRpcKey}`
    );
  }
  return rpc;
}

export const getProviderFromChainSlug = (chainSlug: ChainSlug) => {
  const jsonRpcUrl = getJsonRpcUrl(chainSlug);
  return new ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};

export const getProviderFromChainName = (chainName: HardhatChainName) => {
  return getProviderFromChainSlug(hardhatChainNameToSlug[chainName]);
};

export const getZkWallet = (chainSlug: ChainSlug) => {
  console.log({ chainSlug });
  if (!zkStackChain.includes(chainSlug))
    throw new Error(`Chain ${chainSlug} is not a zkStack chain`);
  if (!process.env.SOCKET_SIGNER_KEY)
    throw new Error("SOCKET_SIGNER_KEY not set");

  const rpc = getJsonRpcUrl(chainSlug);
  console.log({ rpc });
  const provider = new Provider(rpc);
  console.log({ provider });
  return new zkWallet(process.env.SOCKET_SIGNER_KEY, provider);
};
