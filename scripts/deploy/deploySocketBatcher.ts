import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  deployContractWithoutArgs,
  deployContractWithArgs,
  storeAddresses,
  getInstance,
  getRoleHash,
  getAddresses,
} from "./utils";
import { chainSlugs } from "../constants/networks";

import {
  executorAddress,
  transmitterAddress,
  sealGasLimit,
} from "../constants/config";
import { ChainSocketAddresses } from "../../src";

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const network = hre.network.name;
    const addresses = await getAddresses(chainSlugs[network]);

    // SocketBatcher deployment
    let socketBatcher: Contract;
    if (!addresses["SocketBatcher"]) {
      socketBatcher = await deployContractWithArgs(
        "SocketBatcher",
        [socketSigner.address],
        socketSigner,
        "contracts/socket/SocketBatcher.sol"
      );
      addresses["SocketBatcher"] = socketBatcher.address;
      await storeAddresses(addresses, chainSlugs[network]);
    } else {
      socketBatcher = await getInstance(
        "SocketBatcher",
        addresses["SocketBatcher"]
      );
    }

    console.log("SocketBatcher Contract deployed!");
  } catch (error) {
    console.log("Error in deploying SocketBatcher contract", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
