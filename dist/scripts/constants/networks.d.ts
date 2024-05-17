import { ethers } from "ethers";
import { ChainId, HardhatChainName, ChainSlug } from "../../src";
export declare function getJsonRpcUrl(chain: HardhatChainName | ChainId): string;
export declare const getProviderFromChainSlug: (chainSlug: ChainSlug) => ethers.providers.StaticJsonRpcProvider;
