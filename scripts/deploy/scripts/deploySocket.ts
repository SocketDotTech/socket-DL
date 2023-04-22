import { Contract, Wallet } from "ethers";
import {
  deployContractWithArgs,
  storeAddresses,
  getInstance,
} from "../utils";
import { chainSlugs } from "../../constants/networks";

import { sealGasLimit, socketOwner } from "../../constants/config";
import {
  ChainSocketAddresses,
  DeploymentMode,
} from "../../../src";
import deploySwitchboards from "./deploySwitchboard";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

let verificationDetails: any[] = [];
let allDeployed = false;
let addresses: ChainSocketAddresses;
let mode: DeploymentMode;
let signer: SignerWithAddress | Wallet;
let currentChainSlug: number;

/**
 * Deploys network-independent socket contracts
 */
export const deploySocket = async (
  socketSigner: SignerWithAddress | Wallet,
  network: string,
  currentMode: DeploymentMode,
  deployedAddresses: ChainSocketAddresses
): Promise<any> => {
  try {
    addresses = deployedAddresses;
    mode = currentMode;
    signer = socketSigner;
    currentChainSlug = chainSlugs[network];

    const signatureVerifier: Contract = await getOrDeploy(
      "SignatureVerifier",
      "contracts/utils/SignatureVerifier.sol",
      []
    );

    const hasher: Contract = await getOrDeploy(
      "Hasher",
      "contracts/utils/Hasher.sol",
      []
    );

    const capacitorFactory: Contract = await getOrDeploy(
      "CapacitorFactory",
      "contracts/CapacitorFactory.sol",
      [socketOwner]
    );

    const gasPriceOracle: Contract = await getOrDeploy(
      "GasPriceOracle",
      "contracts/GasPriceOracle.sol",
      [socketOwner, chainSlugs[network]]
    );

    const executionManager: Contract = await getOrDeploy(
      "ExecutionManager",
      "contracts/ExecutionManager.sol",
      [gasPriceOracle.address, socketOwner]
    );

    const transmitManager: Contract = await getOrDeploy(
      "TransmitManager",
      "contracts/TransmitManager.sol",
      [
        signatureVerifier.address,
        gasPriceOracle.address,
        socketOwner,
        chainSlugs[network],
        sealGasLimit[network],
      ]
    );

    const socket: Contract = await getOrDeploy(
      "Socket",
      "contracts/socket/Socket.sol",
      [
        chainSlugs[network],
        hasher.address,
        transmitManager.address,
        executionManager.address,
        capacitorFactory.address,
        socketOwner,
      ]
    );

    // switchboards deploy
    const result = await deploySwitchboards(
      network,
      socketSigner,
      addresses,
      verificationDetails,
      mode
    );

    addresses = result["sourceConfig"];
    await storeAddresses(addresses, chainSlugs[network], mode);
    verificationDetails = result["verificationDetails"];

    await getOrDeploy("SocketBatcher", "contracts/socket/SocketBatcher.sol", [
      socketOwner,
    ]);

    // plug deployments
    await getOrDeploy("Counter", "contracts/examples/Counter.sol", [
      socket.address,
    ]);

    allDeployed = true;
    console.log("Contracts deployed!");
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }
  return { verificationDetails, allDeployed };
};

async function getOrDeploy(contractName: string, path: string, args: any[]) {
  let contract: Contract;
  try {
    if (!addresses[contractName]) {
      contract = await deployContractWithArgs(contractName, args, signer);
      verificationDetails.push([contract.address, contractName, path, args]);
      addresses[contractName] = contract.address;
      await storeAddresses(addresses, currentChainSlug, mode);
    } else {
      contract = await getInstance(contractName, addresses[contractName]);
    }
  } catch (error) {
    console.log(error);
    throw error;
  }
  return contract;
}
