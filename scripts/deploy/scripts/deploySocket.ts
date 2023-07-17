import { Contract, Wallet } from "ethers";
import { DeployParams, getOrDeploy, storeAddresses } from "../utils";

import {
  CORE_CONTRACTS,
  ChainSocketAddresses,
  DeploymentMode,
  ChainSlugToKey,
  version,
} from "../../../src";
import deploySwitchboards from "./deploySwitchboard";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { socketOwner, executionManagerVersion, mode } from "../config";
import { overrides } from "../config";

let allDeployed = false;

export interface ReturnObj {
  allDeployed: boolean;
  deployedAddresses: ChainSocketAddresses;
}

/**
 * Deploys network-independent socket contracts
 */
export const deploySocket = async (
  socketSigner: SignerWithAddress | Wallet,
  chainSlug: number,
  currentMode: DeploymentMode,
  deployedAddresses: ChainSocketAddresses
): Promise<ReturnObj> => {
  const deployUtils: DeployParams = {
    addresses: deployedAddresses,
    mode: currentMode,
    signer: socketSigner,
    currentChainSlug: chainSlug,
  };

  try {
    const signatureVerifier: Contract = await getOrDeploy(
      CORE_CONTRACTS.SignatureVerifier,
      "contracts/utils/SignatureVerifier.sol",
      [socketOwner],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.SignatureVerifier] =
      signatureVerifier.address;

    const hasher: Contract = await getOrDeploy(
      CORE_CONTRACTS.Hasher,
      "contracts/utils/Hasher.sol",
      [socketOwner],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.Hasher] = hasher.address;

    const capacitorFactory: Contract = await getOrDeploy(
      CORE_CONTRACTS.CapacitorFactory,
      "contracts/CapacitorFactory.sol",
      [socketOwner],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.CapacitorFactory] =
      capacitorFactory.address;

    const socket: Contract = await getOrDeploy(
      CORE_CONTRACTS.Socket,
      "contracts/socket/Socket.sol",
      [
        chainSlug,
        hasher.address,
        capacitorFactory.address,
        socketOwner,
        version[deployUtils.mode],
      ],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.Socket] = socket.address;

    const executionManager: Contract = await getOrDeploy(
      executionManagerVersion,
      `contracts/${executionManagerVersion}.sol`,
      [socketOwner, chainSlug, socket.address, signatureVerifier.address],
      deployUtils
    );
    deployUtils.addresses[executionManagerVersion] = executionManager.address;

    const transmitManager: Contract = await getOrDeploy(
      CORE_CONTRACTS.TransmitManager,
      "contracts/TransmitManager.sol",
      [socketOwner, chainSlug, socket.address, signatureVerifier.address],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.TransmitManager] =
      transmitManager.address;

    // switchboards deploy
    deployUtils.addresses = await deploySwitchboards(
      ChainSlugToKey[chainSlug],
      socketSigner,
      deployUtils.addresses,
      currentMode
    );

    const socketBatcher: Contract = await getOrDeploy(
      "SocketBatcher",
      "contracts/socket/SocketBatcher.sol",
      [socketOwner],
      deployUtils
    );
    deployUtils.addresses["SocketBatcher"] = socketBatcher.address;

    // plug deployments
    const counter: Contract = await getOrDeploy(
      "Counter",
      "contracts/examples/Counter.sol",
      [socket.address],
      deployUtils
    );
    deployUtils.addresses["Counter"] = counter.address;

    allDeployed = true;
    console.log(deployUtils.addresses);
    console.log("Contracts deployed!");
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }

  await storeAddresses(
    deployUtils.addresses,
    deployUtils.currentChainSlug,
    deployUtils.mode
  );
  return {
    allDeployed,
    deployedAddresses: deployUtils.addresses,
  };
};
