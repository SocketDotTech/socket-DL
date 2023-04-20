import { Contract, Wallet } from "ethers";
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
import address from "../../deployments/addresses.json";

/**
 * Deploys network-independent socket contracts
 */
export const deploySocket = async (
  socketSigner: Wallet,
  network: string
): Promise<any> => {
  let verificationDetails: any[] = [];
  let allDeployed = false;

  try {
    let addresses: ChainSocketAddresses = address[chainSlugs[network]]
      ? address[chainSlugs[network]]
      : {};

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
      await storeAddresses(addresses, chainSlugs[network]);
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
      await storeAddresses(addresses, chainSlugs[network]);
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
        [socketOwner, chainSlugs[network]],
        socketSigner
      );
      verificationDetails.push([
        gasPriceOracle.address,
        "GasPriceOracle",
        "contracts/GasPriceOracle.sol",
        [socketOwner, chainSlugs[network]],
      ]);
      addresses["GasPriceOracle"] = gasPriceOracle.address;
      await storeAddresses(addresses, chainSlugs[network]);

      // const grantee = socketSigner.address;
      // const tx = await gasPriceOracle
      //   .connect(socketSigner)
      // ["grantBatchRole(bytes32[],address[])"](
      //   [getRoleHash("GOVERNANCE_ROLE")],
      //   [grantee]
      // );
      // console.log(
      //   `Assigned gas price oracle batch roles to ${grantee}: ${tx.hash}`
      // );

      // await tx.wait();
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
      await storeAddresses(addresses, chainSlugs[network]);

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
      await storeAddresses(addresses, chainSlugs[network]);

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

    // const tmAddress: string = await gasPriceOracle.transmitManager__();
    // if (tmAddress.toLowerCase() !== transmitManager.address.toLowerCase()) {
    //   const tx = await gasPriceOracle
    //     .connect(socketSigner)
    //     .setTransmitManager(transmitManager.address);
    //   console.log(`Setting transmit manager in oracle: ${tx.hash}`);
    //   await tx.wait();
    // }

    // const oracleOwner: string = await gasPriceOracle.owner();
    // if (oracleOwner.toLowerCase() !== socketOwner.toLowerCase()) {
    //   const tx = await gasPriceOracle
    //     .connect(socketSigner)
    //     .transferOwnership(socketOwner);
    //   console.log(`Setting oracle owner: ${tx.hash}`);
    //   await tx.wait();
    // }

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
      await storeAddresses(addresses, chainSlugs[network]);

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
    await storeAddresses(addresses, chainSlugs[network]);

    verificationDetails = result["verificationDetails"];

    let socketBatcher: Contract;
    if (!addresses["SocketBatcher"]) {
      socketBatcher = await deployContractWithArgs(
        "SocketBatcher",
        [socketOwner],
        socketSigner
      );
      verificationDetails.push([
        socketBatcher.address,
        "SocketBatcher",
        "contracts/socket/SocketBatcher.sol",
        [socketOwner],
      ]);
      addresses["SocketBatcher"] = socketBatcher.address;
      await storeAddresses(addresses, chainSlugs[network]);
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
      await storeAddresses(addresses, chainSlugs[network]);
    } else {
      socket = await getInstance("Counter", addresses["Counter"]);
    }

    allDeployed = true;
    console.log("Contracts deployed!");
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }
  return { verificationDetails, allDeployed };
};
