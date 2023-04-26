import { ethers } from "hardhat";
import { ChainKey } from "../../src";

export const bridgeConsts = {
  inbox: {
    [ChainKey.HARDHAT]: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    mainnet: "0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f",
    goerli: "0x6BEbC4925716945D46F0Ec336D5C2564F419682C",
    arbitrum: ethers.constants.AddressZero,
    "arbitrum-goerli": ethers.constants.AddressZero,
  },
  bridge: {
    [ChainKey.HARDHAT]: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    mainnet: "0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a",
    goerli: "0xaf4159A80B6Cc41ED517DB1c453d1Ef5C2e4dB72",
    arbitrum: ethers.constants.AddressZero,
    "arbitrum-goerli": ethers.constants.AddressZero,
  },
  outbox: {
    [ChainKey.HARDHAT]: ethers.constants.AddressZero,
    mainnet: ethers.constants.AddressZero,
    goerli: ethers.constants.AddressZero,
    arbitrum: ethers.constants.AddressZero,
    "arbitrum-goerli": ethers.constants.AddressZero,
  },
  fxChild: {
    "polygon-mainnet": "0x8397259c983751DAf40400790063935a11afa28a",
    "polygon-mumbai": "0xCf73231F28B7331BBe3124B907840A94851f9f11",
  },
  checkpointManager: {
    [ChainKey.HARDHAT]: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    mainnet: "0x86e4dc95c7fbdbf52e33d563bbdb00823894c287",
    goerli: "0x2890bA17EfE978480615e330ecB65333b880928e",
  },
  fxRoot: {
    [ChainKey.HARDHAT]: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
    mainnet: "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
    goerli: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
  },
  crossDomainMessenger: {
    [ChainKey.HARDHAT]: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
    mainnet: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1",
    optimism: "0x4200000000000000000000000000000000000007",
    "optimism-goerli": "0x4200000000000000000000000000000000000007",
    goerli: "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294",
  },
};
