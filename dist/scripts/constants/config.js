"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.switchboards = exports.getDefaultIntegrationType = exports.timeout = exports.maxAllowedPacketLength = void 0;
const src_1 = require("../../src");
const chainConfig_json_1 = __importDefault(require("../../chainConfig.json"));
const TIMEOUT = 7200;
exports.maxAllowedPacketLength = 10;
// return chain specific timeout if present else default value
const timeout = (chain) => {
    if (chainConfig_json_1.default[chain]) {
        if (chainConfig_json_1.default[chain].timeout && !isNaN(chainConfig_json_1.default[chain].timeout))
            return chainConfig_json_1.default[chain].timeout;
    }
    return TIMEOUT;
};
exports.timeout = timeout;
const getDefaultIntegrationType = (chain, sibling) => {
    var _a;
    return ((_a = exports.switchboards === null || exports.switchboards === void 0 ? void 0 : exports.switchboards[chain]) === null || _a === void 0 ? void 0 : _a[sibling])
        ? src_1.IntegrationTypes.native
        : src_1.IntegrationTypes.fast;
};
exports.getDefaultIntegrationType = getDefaultIntegrationType;
exports.switchboards = {
    [src_1.ChainSlug.ARBITRUM_SEPOLIA]: {
        [src_1.ChainSlug.SEPOLIA]: {
            switchboard: src_1.NativeSwitchboard.ARBITRUM_L2,
        },
    },
    [src_1.ChainSlug.ARBITRUM]: {
        [src_1.ChainSlug.MAINNET]: {
            switchboard: src_1.NativeSwitchboard.ARBITRUM_L2,
        },
    },
    [src_1.ChainSlug.OPTIMISM]: {
        [src_1.ChainSlug.MAINNET]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
    },
    [src_1.ChainSlug.OPTIMISM_SEPOLIA]: {
        [src_1.ChainSlug.SEPOLIA]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
    },
    [src_1.ChainSlug.LYRA_TESTNET]: {
        [src_1.ChainSlug.SEPOLIA]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
    },
    // [ChainSlug.LYRA]: {
    //   [ChainSlug.MAINNET]: {
    //     switchboard: NativeSwitchboard.OPTIMISM,
    //   },
    // },
    [src_1.ChainSlug.POLYGON_MAINNET]: {
        [src_1.ChainSlug.MAINNET]: {
            switchboard: src_1.NativeSwitchboard.POLYGON_L2,
        },
    },
    [src_1.ChainSlug.POLYGON_MUMBAI]: {
        [src_1.ChainSlug.GOERLI]: {
            switchboard: src_1.NativeSwitchboard.POLYGON_L2,
        },
    },
    [src_1.ChainSlug.GOERLI]: {
        [src_1.ChainSlug.POLYGON_MUMBAI]: {
            switchboard: src_1.NativeSwitchboard.POLYGON_L1,
        },
    },
    [src_1.ChainSlug.SEPOLIA]: {
        [src_1.ChainSlug.ARBITRUM_SEPOLIA]: {
            switchboard: src_1.NativeSwitchboard.ARBITRUM_L1,
        },
        [src_1.ChainSlug.OPTIMISM_SEPOLIA]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
        [src_1.ChainSlug.LYRA_TESTNET]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
    },
    [src_1.ChainSlug.MAINNET]: {
        [src_1.ChainSlug.ARBITRUM]: {
            switchboard: src_1.NativeSwitchboard.ARBITRUM_L1,
        },
        [src_1.ChainSlug.OPTIMISM]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
        [src_1.ChainSlug.POLYGON_MAINNET]: {
            switchboard: src_1.NativeSwitchboard.POLYGON_L1,
        },
        [src_1.ChainSlug.LYRA]: {
            switchboard: src_1.NativeSwitchboard.OPTIMISM,
        },
    },
};
