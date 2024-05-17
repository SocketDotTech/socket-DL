"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCurrency = exports.NativeTokens = void 0;
const chainSlug_1 = require("./chainSlug");
// add coingecko token id here
var NativeTokens;
(function (NativeTokens) {
    NativeTokens["ethereum"] = "ethereum";
    NativeTokens["matic-network"] = "matic-network";
    NativeTokens["binancecoin"] = "binancecoin";
    NativeTokens["sx-network-2"] = "sx-network-2";
    NativeTokens["mantle"] = "mantle";
    NativeTokens["no-token"] = "no-token";
})(NativeTokens = exports.NativeTokens || (exports.NativeTokens = {}));
const getCurrency = (chainSlug) => {
    switch (chainSlug) {
        case chainSlug_1.ChainSlug.BSC:
        case chainSlug_1.ChainSlug.BSC_TESTNET:
            return NativeTokens.binancecoin;
        case chainSlug_1.ChainSlug.POLYGON_MAINNET:
        case chainSlug_1.ChainSlug.POLYGON_MUMBAI:
            return NativeTokens["matic-network"];
        case chainSlug_1.ChainSlug.SX_NETWORK_TESTNET:
        case chainSlug_1.ChainSlug.SX_NETWORK:
            return NativeTokens["sx-network-2"];
        case chainSlug_1.ChainSlug.MANTLE:
            return NativeTokens.mantle;
        default:
            return NativeTokens.ethereum;
    }
};
exports.getCurrency = getCurrency;
