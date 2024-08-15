import { Contract, constants } from "ethers";
import {
  DeployParams,
  getInstance,
  getOrDeploy,
  storeAddresses,
} from "../utils";

import {
  CORE_CONTRACTS,
  ChainSocketAddresses,
  DeploymentMode,
  version,
} from "../../../src";
import deploySwitchboards from "./deploySwitchboard";
import { socketOwner, overrides } from "../config/config";
import { maxAllowedPacketLength } from "../../constants";
import { SocketSigner } from "@socket.tech/dl-common";

let allDeployed = false;

export interface ReturnObj {
  allDeployed: boolean;
  deployedAddresses: ChainSocketAddresses;
}

/**
 * Deploys network-independent socket contracts
 */
export const deploySocket = async (
  executionManagerVersion: string,
  socketSigner: SocketSigner,
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
      [socketOwner, maxAllowedPacketLength],
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
      chainSlug,
      socketSigner as SocketSigner,
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

    // safe wrapper deployment
    if (!deployUtils.addresses["Safe"])
      deployUtils.addresses["Safe"] = constants.AddressZero;

    const multisigWrapper: Contract = await getOrDeploy(
      "MultiSigWrapper",
      "contracts/utils/MultiSigWrapper.sol",
      [socketOwner, deployUtils.addresses["Safe"]],
      deployUtils
    );
    deployUtils.addresses["MultiSigWrapper"] = multisigWrapper.address;

    // simulators
    const socketSimulator: Contract = await getOrDeploy(
      "SocketSimulator",
      "contracts/mocks/fee-updater/SocketSimulator.sol",
      [
        chainSlug,
        chainSlug,
        hasher.address,
        signatureVerifier.address,
        version[deployUtils.mode],
      ],
      deployUtils
    );
    deployUtils.addresses["SocketSimulator"] = socketSimulator.address;

    const simulatorUtils: Contract = await getOrDeploy(
      "SimulatorUtils",
      "contracts/mocks/fee-updater/SimulatorUtils.sol",
      [
        socketSimulator.address,
        signatureVerifier.address,
        socketOwner,
        chainSlug,
      ],
      deployUtils
    );
    deployUtils.addresses["SimulatorUtils"] = simulatorUtils.address;

    const switchboardSimulator: Contract = await getOrDeploy(
      "SwitchboardSimulator",
      "contracts/mocks/fee-updater/SwitchboardSimulator.sol",
      [
        socketOwner,
        socketSimulator.address,
        chainSlug,
        1000,
        signatureVerifier.address,
      ],
      deployUtils
    );
    deployUtils.addresses["SwitchboardSimulator"] =
      switchboardSimulator.address;

    // setup
    const simulatorContract = (
      await getInstance("SocketSimulator", socketSimulator.address)
    ).connect(deployUtils.signer);
    let capacitor = await simulatorContract.capacitor({
      ...overrides(chainSlug),
    });
    if (capacitor == constants.AddressZero) {
      const tx = await simulatorContract.setup(
        switchboardSimulator.address,
        simulatorUtils.address,
        {
          ...overrides(chainSlug),
        }
      );
      console.log(tx.hash, "setup for simulator");
      await tx.wait();
    }

    deployUtils.addresses["CapacitorSimulator"] =
      await simulatorContract.capacitor({ ...overrides(chainSlug) });
    deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
      ? deployUtils.addresses.startBlock
      : await socketSigner.provider?.getBlockNumber();

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
