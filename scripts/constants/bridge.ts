import { constants } from "ethers";
import { ChainSlug } from "../../src";

export const bridgeConsts = {
  inbox: {
    [ChainSlug.HARDHAT]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    [ChainSlug.MAINNET]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    [ChainSlug.GOERLI]: "0x6BEbC4925716945D46F0Ec336D5C2564F419682C",
    [ChainSlug.ARBITRUM]: constants.AddressZero,
    [ChainSlug.ARBITRUM_GOERLI]: constants.AddressZero,
  },
  bridge: {
    [ChainSlug.HARDHAT]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    [ChainSlug.MAINNET]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    [ChainSlug.GOERLI]: "0xaf4159A80B6Cc41ED517DB1c453d1Ef5C2e4dB72",
    [ChainSlug.ARBITRUM]: constants.AddressZero,
    [ChainSlug.ARBITRUM_GOERLI]: constants.AddressZero,
  },
  outbox: {
    [ChainSlug.HARDHAT]: constants.AddressZero,
    [ChainSlug.MAINNET]: "0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840",
    [ChainSlug.GOERLI]: "0x45Af9Ed1D03703e480CE7d328fB684bb67DA5049",
    [ChainSlug.ARBITRUM]: constants.AddressZero,
    [ChainSlug.ARBITRUM_GOERLI]: constants.AddressZero,
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
    [ChainSlug.HARDHAT]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
    [ChainSlug.MAINNET]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
    [ChainSlug.OPTIMISM]: "0x4200000000000000000000000000000000000007",
    [ChainSlug.OPTIMISM_GOERLI]: "0x4200000000000000000000000000000000000007",
    [ChainSlug.GOERLI]: "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294",
  },
};
