import { ethers } from "hardhat";
import { ChainKey } from "../../src";

export const bridgeConsts = {
  inbox: {
    [ChainKey.HARDHAT]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    [ChainKey.MAINNET]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    [ChainKey.GOERLI]: "0x6BEbC4925716945D46F0Ec336D5C2564F419682C",
    [ChainKey.ARBITRUM]: ethers.constants.AddressZero,
    [ChainKey.ARBITRUM_GOERLI]: ethers.constants.AddressZero,
  },
  bridge: {
    [ChainKey.HARDHAT]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    [ChainKey.MAINNET]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    [ChainKey.GOERLI]: "0xaf4159A80B6Cc41ED517DB1c453d1Ef5C2e4dB72",
    [ChainKey.ARBITRUM]: ethers.constants.AddressZero,
    [ChainKey.ARBITRUM_GOERLI]: ethers.constants.AddressZero,
  },
  outbox: {
    [ChainKey.HARDHAT]: ethers.constants.AddressZero,
    [ChainKey.MAINNET]: ethers.constants.AddressZero,
    [ChainKey.GOERLI]: ethers.constants.AddressZero,
    [ChainKey.ARBITRUM]: ethers.constants.AddressZero,
    [ChainKey.ARBITRUM_GOERLI]: ethers.constants.AddressZero,
  },
  fxChild: {
    [ChainKey.POLYGON_MAINNET]: "0x8397259c983751DAf40400790063935a11afa28a",
    [ChainKey.POLYGON_MUMBAI]: "0xCf73231F28B7331BBe3124B907840A94851f9f11",
  },
  checkpointManager: {
    [ChainKey.HARDHAT]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    [ChainKey.MAINNET]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    [ChainKey.GOERLI]: "0x2890bA17EfE978480615e330ecB65333b880928e",
  },
  fxRoot: {
    [ChainKey.HARDHAT]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
    [ChainKey.MAINNET]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
    [ChainKey.GOERLI]: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
  },
  crossDomainMessenger: {
    [ChainKey.HARDHAT]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
    [ChainKey.MAINNET]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
    [ChainKey.OPTIMISM]: "0x4200000000000000000000000000000000000007",
    [ChainKey.OPTIMISM_GOERLI]: "0x4200000000000000000000000000000000000007",
    [ChainKey.GOERLI]: "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294",
  },
};
