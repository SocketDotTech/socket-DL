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
    const { socketOwner, counterOwner } = await getNamedAccounts();
    let addresses: ChainSocketAddresses = {
      Counter: "",
      CapacitorFactory: "",
      ExecutionManager: "",
      GasPriceOracle: "",
      Hasher: "",
      SignatureVerifier: "",
      Socket: "",
      TransmitManager: "",
    };

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(
      counterOwner
    );

    const network = hre.network.name;

    let signatureVerifier: Contract;
    if (!addresses["SignatureVerifier"]) {
      signatureVerifier = await deployContractWithoutArgs(
        "SignatureVerifier",
        socketSigner,
        "contracts/utils/SignatureVerifier.sol"
      );
      addresses["SignatureVerifier"] = signatureVerifier.address;
      await storeAddresses(addresses, chainSlugs[network]);
    } else {
      signatureVerifier = await getInstance(
        "SignatureVerifier",
        addresses["SignatureVerifier"]
      );
    }

    let hasher: Contract;
    if (!addresses["Hasher"]) {
      hasher = await deployContractWithoutArgs(
        "Hasher",
        socketSigner,
        "contracts/utils/Hasher.sol"
      );
      addresses["Hasher"] = hasher.address;
      await storeAddresses(addresses, chainSlugs[network]);
    } else {
      hasher = await getInstance("Hasher", addresses["Hasher"]);
    }

    let capacitorFactory: Contract;
    if (!addresses["CapacitorFactory"]) {
      capacitorFactory = await deployContractWithArgs(
        "CapacitorFactory",
        [socketSigner.address],
        socketSigner,
        "contracts/CapacitorFactory.sol"
      );
      addresses["CapacitorFactory"] = capacitorFactory.address;
      await storeAddresses(addresses, chainSlugs[network]);
    } else {
      capacitorFactory = await getInstance(
        "CapacitorFactory",
        addresses["CapacitorFactory"]
      );
    }

    let gasPriceOracle: Contract;
    if (!addresses["GasPriceOracle"]) {
      gasPriceOracle = await deployContractWithArgs(
        "GasPriceOracle",
        [socketSigner.address, chainSlugs[network]],
        socketSigner,
        "contracts/GasPriceOracle.sol"
      );
      addresses["GasPriceOracle"] = gasPriceOracle.address;
      await storeAddresses(addresses, chainSlugs[network]);

      const grantee = socketSigner.address;
      const tx = await gasPriceOracle
        .connect(socketSigner)
        ["grantBatchRole(bytes32[],address[])"](
          [getRoleHash("RESCUE_ROLE"), getRoleHash("GOVERNANCE_ROLE")],
          [grantee, grantee]
        );
      console.log(
        `Assigned gas price oracle batch roles to ${grantee}: ${tx.hash}`
      );

      await tx.wait();
    } else {
      gasPriceOracle = await getInstance(
        "GasPriceOracle",
        addresses["GasPriceOracle"]
      );
    }

    let executionManager: Contract;
    if (!addresses["ExecutionManager"]) {
      executionManager = await deployContractWithArgs(
        "ExecutionManager",
        [gasPriceOracle.address, socketSigner.address],
        socketSigner,
        "contracts/ExecutionManager.sol"
      );
      addresses["ExecutionManager"] = executionManager.address;
      await storeAddresses(addresses, chainSlugs[network]);

      const grantee = socketSigner.address;
      const tx = await executionManager
        .connect(socketSigner)
        ["grantBatchRole(bytes32[],address[])"](
          [
            getRoleHash("WITHDRAW_ROLE"),
            getRoleHash("RESCUE_ROLE"),
            getRoleHash("GOVERNANCE_ROLE"),
            getRoleHash("EXECUTOR_ROLE"),
          ],
          [grantee, grantee, grantee, executorAddress[network]]
        );
      console.log(
        `Assigned execution manager batch roles to ${grantee}: ${tx.hash}`
      );

      await tx.wait();
    } else {
      executionManager = await getInstance(
        "ExecutionManager",
        addresses["ExecutionManager"]
      );
    }

    let transmitManager: Contract;
    if (!addresses["TransmitManager"]) {
      transmitManager = await deployContractWithArgs(
        "TransmitManager",
        [
          signatureVerifier.address,
          gasPriceOracle.address,
          socketSigner.address,
          chainSlugs[network],
          sealGasLimit[network],
        ],
        socketSigner,
        "contracts/TransmitManager.sol"
      );
      addresses["TransmitManager"] = transmitManager.address;
      await storeAddresses(addresses, chainSlugs[network]);

      const grantee = socketSigner.address;
      const tx = await transmitManager
        .connect(socketSigner)
        ["grantBatchRole(bytes32[],address[])"](
          [
            getRoleHash("WITHDRAW_ROLE"),
            getRoleHash("RESCUE_ROLE"),
            getRoleHash("GOVERNANCE_ROLE"),
            getRoleHash("GAS_LIMIT_UPDATER_ROLE"),
          ],
          [grantee, grantee, grantee, transmitterAddress[network]]
        );
      console.log(
        `Assigned transmit manager batch roles to ${grantee}: ${tx.hash}`
      );

      await tx.wait();

      //grant transmitter role to transmitter-address for current network
      const grantTransmitterRoleTxn = await transmitManager
        .connect(socketSigner)
        ["grantRole(string,uint256,address)"](
          "TRANSMITTER_ROLE",
          chainSlugs[network],
          transmitterAddress[network]
        );

      console.log(
        `Setting transmitter role for current chain: ${grantTransmitterRoleTxn.hash}`
      );
      await grantTransmitterRoleTxn.wait();
    } else {
      transmitManager = await getInstance(
        "TransmitManager",
        addresses["TransmitManager"]
      );
    }

    const tmAddress: string = await gasPriceOracle.transmitManager__();
    if (tmAddress.toLowerCase() !== transmitManager.address.toLowerCase()) {
      const tx = await gasPriceOracle
        .connect(socketSigner)
        .setTransmitManager(transmitManager.address);
      console.log(`Setting transmit manager in oracle: ${tx.hash}`);
      await tx.wait();
    }

    let socket: Contract;
    if (!addresses["Socket"]) {
      socket = await deployContractWithArgs(
        "Socket",
        [
          chainSlugs[network],
          hasher.address,
          transmitManager.address,
          executionManager.address,
          capacitorFactory.address,
          socketSigner.address,
        ],
        socketSigner,
        "contracts/socket/Socket.sol"
      );
      addresses["Socket"] = socket.address;
      await storeAddresses(addresses, chainSlugs[network]);

      const grantee = socketSigner.address;
      const tx = await socket
        .connect(socketSigner)
        ["grantBatchRole(bytes32[],address[])"](
          [getRoleHash("RESCUE_ROLE"), getRoleHash("GOVERNANCE_ROLE")],
          [grantee, grantee]
        );
      console.log(
        `Assigned transmit manager batch roles to ${grantee}: ${tx.hash}`
      );

      await tx.wait();
    } else {
      socket = await getInstance("Socket", addresses["Socket"]);
    }
    // plug deployments
    let counter: Contract;
    if (!addresses["Counter"]) {
      counter = await deployContractWithArgs(
        "Counter",
        [socket.address],
        counterSigner,
        "contracts/examples/Counter.sol"
      );
      addresses["Counter"] = counter.address;
      await storeAddresses(addresses, chainSlugs[network]);
    } else {
      socket = await getInstance("Counter", addresses["Counter"]);
    }
    console.log("Contracts deployed!");
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
