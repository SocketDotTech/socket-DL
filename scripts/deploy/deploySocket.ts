import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract, Wallet } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  deployContractWithoutArgs,
  deployContractWithArgs,
  storeAddresses,
  getInstance,
  getRoleHash,
} from "./utils";
import { chainSlugs } from "../constants/networks";

import { sealGasLimit, socketOwner } from "../constants/config";
import { ChainSocketAddresses } from "../../src";
import deploySwitchboards from "./deploySwitchboard";

let addresses: ChainSocketAddresses = {
  Counter: "",
  CapacitorFactory: "",
  ExecutionManager: "",
  GasPriceOracle: "",
  Hasher: "",
  SignatureVerifier: "",
  Socket: "",
  TransmitManager: "",
  FastSwitchboard: "",
  OptimisticSwitchboard: "",
  SocketBatcher: "",
};

/**
 * Deploys network-independent socket contracts
 */
export const deploySocket = async (
  socketSigner: Wallet,
  network: string
): Promise<any> => {
  try {
    let verificationDetails: any[] = [];

    let signatureVerifier: Contract;
    if (!addresses["SignatureVerifier"]) {
      signatureVerifier = await deployContractWithoutArgs(
        "SignatureVerifier",
        socketSigner
      );

      verificationDetails.push([
        signatureVerifier.address,
        "SignatureVerifier",
        "contracts/utils/SignatureVerifier.sol",
        [],
      ]);
      addresses["SignatureVerifier"] = signatureVerifier.address;
    } else {
      signatureVerifier = await getInstance(
        "SignatureVerifier",
        addresses["SignatureVerifier"]
      );
    }

    let hasher: Contract;
    if (!addresses["Hasher"]) {
      hasher = await deployContractWithoutArgs("Hasher", socketSigner);
      verificationDetails.push([
        hasher.address,
        "Hasher",
        "contracts/utils/Hasher.sol",
        [],
      ]);
      addresses["Hasher"] = hasher.address;
    } else {
      hasher = await getInstance("Hasher", addresses["Hasher"]);
    }

    let capacitorFactory: Contract;
    if (!addresses["CapacitorFactory"]) {
      capacitorFactory = await deployContractWithArgs(
        "CapacitorFactory",
        [socketOwner],
        socketSigner
      );
      verificationDetails.push([
        capacitorFactory.address,
        "CapacitorFactory",
        "contracts/CapacitorFactory.sol",
        [socketOwner],
      ]);
      addresses["CapacitorFactory"] = capacitorFactory.address;
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
        socketSigner
      );
      verificationDetails.push([
        gasPriceOracle.address,
        "GasPriceOracle",
        "contracts/GasPriceOracle.sol",
        [socketSigner.address, chainSlugs[network]],
      ]);
      addresses["GasPriceOracle"] = gasPriceOracle.address;

      const grantee = socketSigner.address;
      const tx = await gasPriceOracle
        .connect(socketSigner)
        ["grantBatchRole(bytes32[],address[])"](
          [getRoleHash("GOVERNANCE_ROLE")],
          [grantee]
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
        [gasPriceOracle.address, socketOwner],
        socketSigner
      );
      verificationDetails.push([
        executionManager.address,
        "ExecutionManager",
        "contracts/ExecutionManager.sol",
        [gasPriceOracle.address, socketOwner],
      ]);

      addresses["ExecutionManager"] = executionManager.address;

      // const grantee = socketOwner;
      // const tx = await executionManager
      //   .connect(socketSigner)
      // ["grantBatchRole(bytes32[],address[])"](
      //   [
      //     getRoleHash("WITHDRAW_ROLE"),
      //     getRoleHash("RESCUE_ROLE"),
      //     getRoleHash("GOVERNANCE_ROLE"),
      //     getRoleHash("EXECUTOR_ROLE"),
      //   ],
      //   [grantee, grantee, grantee, executorAddress[network]]
      // );
      // console.log(
      //   `Assigned execution manager batch roles to ${grantee}: ${tx.hash}`
      // );

      // await tx.wait();
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
          socketOwner,
          chainSlugs[network],
          sealGasLimit[network],
        ],
        socketSigner
      );

      verificationDetails.push([
        transmitManager.address,
        "TransmitManager",
        "contracts/TransmitManager.sol",
        [
          signatureVerifier.address,
          gasPriceOracle.address,
          socketOwner,
          chainSlugs[network],
          sealGasLimit[network],
        ],
      ]);
      addresses["TransmitManager"] = transmitManager.address;

      // const grantee = socketOwner;
      // const tx = await transmitManager
      //   .connect(socketSigner)
      // ["grantBatchRole(bytes32[],address[])"](
      //   [
      //     getRoleHash("WITHDRAW_ROLE"),
      //     getRoleHash("RESCUE_ROLE"),
      //     getRoleHash("GOVERNANCE_ROLE"),
      //     getRoleHash("GAS_LIMIT_UPDATER_ROLE"),
      //   ],
      //   [grantee, grantee, grantee, transmitterAddress[network]]
      // );
      // console.log(
      //   `Assigned transmit manager batch roles to ${grantee}: ${tx.hash}`
      // );

      // await tx.wait();

      //grant transmitter role to transmitter-address for current network
      // const grantTransmitterRoleTxn = await transmitManager
      //   .connect(socketSigner)
      // ["grantRole(string,uint256,address)"](
      //   "TRANSMITTER_ROLE",
      //   chainSlugs[network],
      //   transmitterAddress[network]
      // );

      // console.log(
      //   `Setting transmitter role for current chain: ${grantTransmitterRoleTxn.hash}`
      // );
      // await grantTransmitterRoleTxn.wait();
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

    const oracleOwner: string = await gasPriceOracle.owner();
    if (oracleOwner.toLowerCase() !== socketOwner.toLowerCase()) {
      const tx = await gasPriceOracle
        .connect(socketSigner)
        .transferOwnership(socketOwner);
      console.log(`Setting oracle owner: ${tx.hash}`);
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
          socketOwner,
        ],
        socketSigner
      );
      verificationDetails.push([
        socket.address,
        "Socket",
        "contracts/socket/Socket.sol",
        [
          chainSlugs[network],
          hasher.address,
          transmitManager.address,
          executionManager.address,
          capacitorFactory.address,
          socketOwner,
        ],
      ]);

      addresses["Socket"] = socket.address;

      // const grantee = socketOwner;
      // const tx = await socket
      //   .connect(socketSigner)
      // ["grantBatchRole(bytes32[],address[])"](
      //   [getRoleHash("RESCUE_ROLE"), getRoleHash("GOVERNANCE_ROLE")],
      //   [grantee, grantee]
      // );
      // console.log(`Assigned socket batch roles to ${grantee}: ${tx.hash}`);

      // await tx.wait();
    } else {
      socket = await getInstance("Socket", addresses["Socket"]);
    }

    // switchboards deploy
    const result = await deploySwitchboards(
      network,
      socketSigner,
      addresses,
      verificationDetails
    );

    addresses = result["sourceConfig"];
    verificationDetails = result["verificationDetails"];

    let socketBatcher: Contract;
    if (!addresses["SocketBatcher"]) {
      socketBatcher = await deployContractWithArgs(
        "SocketBatcher",
        [socketSigner.address],
        socketSigner
      );
      verificationDetails.push([
        socketBatcher.address,
        "SocketBatcher",
        "contracts/socket/SocketBatcher.sol",
        [socketSigner.address],
      ]);
      addresses["SocketBatcher"] = socketBatcher.address;
    } else {
      socketBatcher = await getInstance(
        "SocketBatcher",
        addresses["SocketBatcher"]
      );
    }

    // plug deployments
    let counter: Contract;
    if (!addresses["Counter"]) {
      counter = await deployContractWithArgs(
        "Counter",
        [socket.address],
        socketSigner
      );
      verificationDetails.push([
        counter.address,
        "Counter",
        "contracts/examples/Counter.sol",
        [socket.address],
      ]);
      addresses["Counter"] = counter.address;
    } else {
      socket = await getInstance("Counter", addresses["Counter"]);
    }
    console.log("Contracts deployed!");
    await storeAddresses(addresses, chainSlugs[network]);

    return verificationDetails;
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
    throw error;
  }
};
