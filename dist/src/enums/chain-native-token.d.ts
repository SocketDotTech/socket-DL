import { ChainSlug } from "./chainSlug";
export declare enum NativeTokens {
    "ethereum" = "ethereum",
    "matic-network" = "matic-network",
    "binancecoin" = "binancecoin",
    "sx-network-2" = "sx-network-2",
    "mantle" = "mantle",
    "no-token" = "no-token"
}
export declare const getCurrency: (chainSlug: ChainSlug) => NativeTokens.ethereum | (typeof NativeTokens)["matic-network"] | NativeTokens.binancecoin | (typeof NativeTokens)["sx-network-2"] | NativeTokens.mantle;
