import { Contract, utils } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { chainSlugs, timeout, watcherAddress } from "../../constants";

const executionOverhead: {
  [key: string]: number;
} = {
  "bsc-testnet": 300000,
  "polygon-mainnet": 300000,
  bsc: 300000,
  "polygon-mumbai": 300000,
  "arbitrum-goerli": 300000,
  "optimism-goerli": 300000,
  goerli: 300000,
  hardhat: 300000,
  arbitrum: 300000,
  optimism: 300000,
  mainnet: 300000,
};

export const optimisticSwitchboard = (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "OptimisticSwitchboard",
    args: [signerAddress, oracleAddress, chainSlugs[network], timeout[network]],
    path: "contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol",
  };
};
