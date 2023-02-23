import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  deployContractWithoutArgs,
  deployContractWithArgs,
  storeAddresses,
  getInstance,
} from "./utils";
import { chainIds } from "../constants/networks";

import {
  executorAddress,
  transmitterAddress,
  EXECUTOR_ROLE,
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
      await storeAddresses(addresses, chainIds[network]);
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
      await storeAddresses(addresses, chainIds[network]);
    } else {
      hasher = await getInstance("Hasher", addresses["Hasher"]);
    }

    let capacitorFactory: Contract;
    if (!addresses["CapacitorFactory"]) {
      capacitorFactory = await deployContractWithoutArgs(
        "CapacitorFactory",
        socketSigner,
        "contracts/CapacitorFactory.sol"
      );
      addresses["CapacitorFactory"] = capacitorFactory.address;
      await storeAddresses(addresses, chainIds[network]);
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
        [socketSigner.address, chainIds[network]],
        socketSigner,
        "contracts/GasPriceOracle.sol"
      );
      addresses["GasPriceOracle"] = gasPriceOracle.address;
      await storeAddresses(addresses, chainIds[network]);
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
      await storeAddresses(addresses, chainIds[network]);
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
          chainIds[network],
          sealGasLimit[network],
        ],
        socketSigner,
        "contracts/TransmitManager.sol"
      );
      addresses["TransmitManager"] = transmitManager.address;
      await storeAddresses(addresses, chainIds[network]);
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

      //grant transmitter role to transmitter-address
      const transmitter = transmitterAddress[network];

      const grantTransmitterRoleTxn = await transmitManager
        .connect(socketSigner)
        .grantTransmitterRole(chainIds[network], transmitter);

      console.log(
        `Setting transmitter manager in oracle has transactionHash: ${grantTransmitterRoleTxn.hash}`
      );
      await grantTransmitterRoleTxn.wait();
    }

    let socket: Contract;
    if (!addresses["Socket"]) {
      socket = await deployContractWithArgs(
        "Socket",
        [
          chainIds[network],
          hasher.address,
          transmitManager.address,
          executionManager.address,
          capacitorFactory.address,
        ],
        socketSigner,
        "contracts/socket/Socket.sol"
      );
      addresses["Socket"] = socket.address;
      await storeAddresses(addresses, chainIds[network]);
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
      await storeAddresses(addresses, chainIds[network]);
    } else {
      socket = await getInstance("Counter", addresses["Counter"]);
    }
    console.log("Contracts deployed!");

    // configure
    const tx = await executionManager
      .connect(socketSigner)
      .grantRole(EXECUTOR_ROLE, executorAddress[network]);
    console.log(
      `Assigned executor role to ${executorAddress[network]}: ${tx.hash}`
    );

    await tx.wait();
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
