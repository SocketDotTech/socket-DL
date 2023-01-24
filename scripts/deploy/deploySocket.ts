import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContractWithoutArgs, deployContractWithArgs, storeAddresses } from "./utils";
import { chainIds } from "../constants/networks";

import { executorAddress, sealGasLimit } from "../constants/config";
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
      Hasher: "",
      SignatureVerifier: "",
      Socket: "",
      CapacitorFactory: "",
      GasPriceOracle: "",
      TransmitManager: ""
    };

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(
      counterOwner
    );

    const network = hre.network.name;

    const signatureVerifier: Contract = await deployContractWithoutArgs(
      "SignatureVerifier",
      socketSigner,
      "contracts/utils/SignatureVerifier.sol"
    );
    addresses["SignatureVerifier"] = signatureVerifier.address;
    await storeAddresses(addresses, chainIds[network]);

    const hasher: Contract = await deployContractWithoutArgs(
      "Hasher",
      socketSigner,
      "contracts/utils/Hasher.sol"
    );
    addresses["Hasher"] = hasher.address;
    await storeAddresses(addresses, chainIds[network]);

    const capacitorFactory: Contract = await deployContractWithoutArgs(
      "CapacitorFactory",
      socketSigner,
      "contracts/CapacitorFactory.sol"
    );
    addresses["CapacitorFactory"] = capacitorFactory.address;
    await storeAddresses(addresses, chainIds[network]);

    const gasPriceOracle: Contract = await deployContractWithArgs(
      "GasPriceOracle",
      [socketSigner.address],
      socketSigner,
      "contracts/GasPriceOracle.sol"
    );

    addresses["GasPriceOracle"] = gasPriceOracle.address;
    await storeAddresses(addresses, chainIds[network]);

    const transmitManager: Contract = await deployContractWithArgs(
      "TransmitManager",
      [signatureVerifier.address, gasPriceOracle.address, socketSigner.address, chainIds[network], sealGasLimit[network]],
      socketSigner,
      "contracts/TransmitManager.sol"
    );
    addresses["TransmitManager"] = transmitManager.address;
    await storeAddresses(addresses, chainIds[network]);

    const tmAddress: string = await gasPriceOracle.transmitManager();
    if (tmAddress.toLowerCase() !== (transmitManager.address).toLowerCase()) {
      const tx = await gasPriceOracle
        .connect(socketSigner)
        .setTransmitManager(transmitManager.address);
      console.log(`Setting transmit manager in oracle: ${tx.hash}`);
      await tx.wait();
    }

    const socket: Contract = await deployContractWithArgs(
      "Socket",
      [
        chainIds[network],
        hasher.address,
        transmitManager.address,
        capacitorFactory.address,
      ],
      socketSigner,
      "contracts/socket/Socket.sol"
    );
    addresses["Socket"] = socket.address;
    await storeAddresses(addresses, chainIds[network]);

    // plug deployments
    const counter: Contract = await deployContractWithArgs("Counter", [socket.address], counterSigner, "contracts/examples/Counter.sol");
    addresses["Counter"] = counter.address;
    await storeAddresses(addresses, chainIds[network]);
    console.log("Contracts deployed!");

    // configure
    const tx = await socket
      .connect(socketSigner)
      .grantExecutorRole(executorAddress[network]);
    console.log(`Assigned executor role to ${executorAddress[network]}: ${tx.hash}`);
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
