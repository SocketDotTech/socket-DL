"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.bridgeConsts = void 0;
const ethers_1 = require("ethers");
const src_1 = require("../../src");
exports.bridgeConsts = {
    inbox: {
        [src_1.ChainSlug.MAINNET]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
        [src_1.ChainSlug.SEPOLIA]: "0xaAe29B0366299461418F5324a79Afc425BE5ae21",
        [src_1.ChainSlug.ARBITRUM]: ethers_1.constants.AddressZero,
        [src_1.ChainSlug.ARBITRUM_SEPOLIA]: ethers_1.constants.AddressZero,
    },
    bridge: {
        [src_1.ChainSlug.MAINNET]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
        [src_1.ChainSlug.SEPOLIA]: "0x38f918D0E9F1b721EDaA41302E399fa1B79333a9",
        [src_1.ChainSlug.ARBITRUM]: ethers_1.constants.AddressZero,
        [src_1.ChainSlug.ARBITRUM_SEPOLIA]: ethers_1.constants.AddressZero,
    },
    outbox: {
        [src_1.ChainSlug.MAINNET]: "0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840",
        [src_1.ChainSlug.SEPOLIA]: "0x65f07C7D521164a4d5DaC6eB8Fac8DA067A3B78F",
        [src_1.ChainSlug.ARBITRUM]: ethers_1.constants.AddressZero,
        [src_1.ChainSlug.ARBITRUM_SEPOLIA]: ethers_1.constants.AddressZero,
    },
    fxChild: {
        [src_1.ChainSlug.POLYGON_MAINNET]: "0x8397259c983751DAf40400790063935a11afa28a",
        [src_1.ChainSlug.POLYGON_MUMBAI]: "0xCf73231F28B7331BBe3124B907840A94851f9f11",
    },
    checkpointManager: {
        [src_1.ChainSlug.HARDHAT]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
        [src_1.ChainSlug.MAINNET]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
        [src_1.ChainSlug.GOERLI]: "0x2890bA17EfE978480615e330ecB65333b880928e",
    },
    fxRoot: {
        [src_1.ChainSlug.HARDHAT]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
        [src_1.ChainSlug.MAINNET]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
        [src_1.ChainSlug.GOERLI]: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
    },
    crossDomainMessenger: {
        [src_1.ChainSlug.OPTIMISM]: {
            [src_1.ChainSlug.MAINNET]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
            [src_1.ChainSlug.OPTIMISM]: "0x4200000000000000000000000000000000000007",
        },
        [src_1.ChainSlug.OPTIMISM_GOERLI]: {
            [src_1.ChainSlug.GOERLI]: "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294",
            [src_1.ChainSlug.OPTIMISM_GOERLI]: "0x4200000000000000000000000000000000000007",
        },
        [src_1.ChainSlug.OPTIMISM_SEPOLIA]: {
            [src_1.ChainSlug.SEPOLIA]: "0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef",
            [src_1.ChainSlug.OPTIMISM_SEPOLIA]: "0x4200000000000000000000000000000000000007",
        },
        [src_1.ChainSlug.LYRA_TESTNET]: {
            [src_1.ChainSlug.SEPOLIA]: "0x28976A1DF6e6689Bfe555780CD46dcFcF5552979",
            [src_1.ChainSlug.LYRA_TESTNET]: "0x4200000000000000000000000000000000000007",
        },
        [src_1.ChainSlug.LYRA]: {
            [src_1.ChainSlug.MAINNET]: "0x5456f02c08e9A018E42C39b351328E5AA864174A",
            [src_1.ChainSlug.LYRA]: "0x4200000000000000000000000000000000000007",
        },
    },
};
