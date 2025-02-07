import { Contract, Event, Transaction, constants, utils } from "ethers";
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
  useSafe: boolean,
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
    // safe wrapper deployment
    const safe: Contract = await getOrDeploy(
      "SafeL2",
      "contracts/utils/multisig/SafeL2.sol",
      [],
      deployUtils
    );
    deployUtils.addresses["SafeL2"] = safe.address;

    const safeProxyFactory: Contract = await getOrDeploy(
      "SafeProxyFactory",
      "contracts/utils/multisig/proxies/SafeProxyFactory.sol",
      [],
      deployUtils
    );
    deployUtils.addresses["SafeProxyFactory"] = safeProxyFactory.address;

    if (!deployUtils.addresses["SocketSafeProxy"]) {
      const proxyAddress = await createSocketSafe(
        safeProxyFactory,
        deployUtils.addresses["SafeL2"],
        [socketOwner]
      );
      deployUtils.addresses["SocketSafeProxy"] = proxyAddress;
    }

    const multisigWrapper: Contract = await getOrDeploy(
      "MultiSigWrapper",
      "contracts/utils/multisig/MultiSigWrapper.sol",
      [socketOwner, deployUtils.addresses["SocketSafeProxy"]],
      deployUtils
    );
    deployUtils.addresses["MultiSigWrapper"] = multisigWrapper.address;

    const owner = useSafe
      ? deployUtils.addresses["SocketSafeProxy"]
      : socketOwner;
    const signatureVerifier: Contract = await getOrDeploy(
      CORE_CONTRACTS.SignatureVerifier,
      "contracts/utils/SignatureVerifier.sol",
      [owner],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.SignatureVerifier] =
      signatureVerifier.address;

    const hasher: Contract = await getOrDeploy(
      CORE_CONTRACTS.Hasher,
      "contracts/utils/Hasher.sol",
      [owner],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.Hasher] = hasher.address;

    const capacitorFactory: Contract = await getOrDeploy(
      CORE_CONTRACTS.CapacitorFactory,
      "contracts/CapacitorFactory.sol",
      [owner, maxAllowedPacketLength],
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
        owner,
        version[deployUtils.mode],
      ],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.Socket] = socket.address;

    const executionManager: Contract = await getOrDeploy(
      executionManagerVersion,
      `contracts/${executionManagerVersion}.sol`,
      [owner, chainSlug, socket.address, signatureVerifier.address],
      deployUtils
    );
    deployUtils.addresses[executionManagerVersion] = executionManager.address;

    const transmitManager: Contract = await getOrDeploy(
      CORE_CONTRACTS.TransmitManager,
      "contracts/TransmitManager.sol",
      [owner, chainSlug, socket.address, signatureVerifier.address],
      deployUtils
    );
    deployUtils.addresses[CORE_CONTRACTS.TransmitManager] =
      transmitManager.address;

    // switchboards deploy
    deployUtils.addresses = await deploySwitchboards(
      chainSlug,
      owner,
      socketSigner as SocketSigner,
      deployUtils.addresses,
      currentMode
    );

    const socketBatcher: Contract = await getOrDeploy(
      "SocketBatcher",
      "contracts/socket/SocketBatcher.sol",
      [owner],
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
      ...(await overrides(chainSlug)),
    });
    if (capacitor == constants.AddressZero) {
      const tx = await simulatorContract.setup(
        switchboardSimulator.address,
        simulatorUtils.address,
        {
          ...(await overrides(chainSlug)),
        }
      );
      console.log(tx.hash, "setup for simulator");
      await tx.wait();
    }

    deployUtils.addresses["CapacitorSimulator"] =
      await simulatorContract.capacitor({ ...(await overrides(chainSlug)) });
    deployUtils.addresses.startBlock = deployUtils.addresses.startBlock
      ? deployUtils.addresses.startBlock
      : await socketSigner.provider?.getBlockNumber();

    allDeployed = true;
    console.log(deployUtils.addresses);
    console.log("Contracts deployed!");
  } catch (error) {
    console.log(
      "Error in deploying setup contracts for chain",
      chainSlug,
      error
    );
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

// Assuming you are in a contract context
async function createSocketSafe(
  safeProxyFactory: Contract,
  safeAddress: string,
  owners: string[]
) {
  const addressZero = "0x0000000000000000000000000000000000000000";
  const functionSignature =
    "setup(address[],uint256,address,bytes,address,address,uint256,address)";
  const functionSelector = utils.id(functionSignature).slice(0, 10);

  const encodedParameters = utils.defaultAbiCoder.encode(
    [
      "address[]",
      "uint256",
      "address",
      "bytes",
      "address",
      "address",
      "uint256",
      "address",
    ],
    [
      owners,
      owners.length,
      addressZero,
      "0x",
      addressZero,
      addressZero,
      0,
      addressZero,
    ]
  );
  const encodedData = functionSelector + encodedParameters.slice(2); // Remove '0x' from encodedParameters

  const tx = await safeProxyFactory.createChainSpecificProxyWithNonce(
    safeAddress,
    encodedData,
    0,
    {
      ...(await overrides(await safeProxyFactory.signer.getChainId())),
    }
  );
  const receipt = await tx.wait();

  const safeSetupEvent = receipt.events?.find(
    (event: Event) => event.event === "ProxyCreation"
  );

  if (safeSetupEvent) {
    const proxy = safeSetupEvent.args.proxy;
    return proxy;
  } else {
    throw new Error(
      "Safe proxy created event not found in the transaction receipt"
    );
  }
}
