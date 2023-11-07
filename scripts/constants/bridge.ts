import { constants } from "ethers";
import { ChainSlug } from "../../src";

export const bridgeConsts = {
  inbox: {
    [ChainSlug.MAINNET]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    [ChainSlug.SEPOLIA]: "0xaAe29B0366299461418F5324a79Afc425BE5ae21",
    [ChainSlug.ARBITRUM]: constants.AddressZero,
    [ChainSlug.ARBITRUM_SEPOLIA]: constants.AddressZero,
  },
  bridge: {
    [ChainSlug.MAINNET]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    [ChainSlug.SEPOLIA]: "0x38f918D0E9F1b721EDaA41302E399fa1B79333a9",
    [ChainSlug.ARBITRUM]: constants.AddressZero,
    [ChainSlug.ARBITRUM_SEPOLIA]: constants.AddressZero,
  },
  outbox: {
    [ChainSlug.MAINNET]: "0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840",
    [ChainSlug.SEPOLIA]: "0x65f07C7D521164a4d5DaC6eB8Fac8DA067A3B78F",
    [ChainSlug.ARBITRUM]: constants.AddressZero,
    [ChainSlug.ARBITRUM_SEPOLIA]: constants.AddressZero,
  },
  fxChild: {
    [ChainSlug.POLYGON_MAINNET]: "0x8397259c983751DAf40400790063935a11afa28a",
    [ChainSlug.POLYGON_MUMBAI]: "0xCf73231F28B7331BBe3124B907840A94851f9f11",
  },
  checkpointManager: {
    [ChainSlug.HARDHAT]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    [ChainSlug.MAINNET]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    [ChainSlug.GOERLI]: "0x2890bA17EfE978480615e330ecB65333b880928e",
  },
  fxRoot: {
    [ChainSlug.HARDHAT]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
    [ChainSlug.MAINNET]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
    [ChainSlug.GOERLI]: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
  },
  crossDomainMessenger: {
    [ChainSlug.OPTIMISM]: {
      [ChainSlug.MAINNET]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
      [ChainSlug.OPTIMISM]: "0x4200000000000000000000000000000000000007",
    },
    [ChainSlug.OPTIMISM_GOERLI]: {
      [ChainSlug.GOERLI]: "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294",
      [ChainSlug.OPTIMISM_GOERLI]: "0x4200000000000000000000000000000000000007",
    },
    [ChainSlug.OPTIMISM_SEPOLIA]: {
      [ChainSlug.SEPOLIA]: "0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef",
      [ChainSlug.OPTIMISM_SEPOLIA]:
        "0x4200000000000000000000000000000000000007",
    },
    [ChainSlug.LYRA_TESTNET]: {
      [ChainSlug.SEPOLIA]: "0x28976A1DF6e6689Bfe555780CD46dcFcF5552979",
      [ChainSlug.LYRA_TESTNET]: "0x4200000000000000000000000000000000000007",
    },
  },
};
