import { Contract, Wallet } from "ethers";
import { deployContractWithArgs, storeAddresses, getInstance } from "../utils";
import { chainSlugs } from "../../constants/networks";

import { sealGasLimit, socketOwner } from "../../constants/config";
import { ChainSocketAddresses, DeploymentMode } from "../../../src";
import deploySwitchboards from "./deploySwitchboard";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { networkToChainSlug } from "../../constants";

let verificationDetails: any[] = [];
let allDeployed = false;

/**
 * Deploys network-independent socket contracts
 */
export const deploySocket = async (
  socketSigner: SignerWithAddress | Wallet,
  network: string,
  currentMode: DeploymentMode,
  deployedAddresses: ChainSocketAddresses
): Promise<any> => {
  const deployUtils = {
    addresses: deployedAddresses,
    mode: currentMode,
    signer: socketSigner,
    currentChainSlug: chainSlugs[network],
  };

  try {
    const signatureVerifier: Contract = await getOrDeploy(
      "SignatureVerifier",
      "contracts/utils/SignatureVerifier.sol",
      [],
      deployUtils
    );
    deployUtils.addresses["SignatureVerifier"] = signatureVerifier.address;
    console.log(deployUtils.addresses);


    const hasher: Contract = await getOrDeploy(
      "Hasher",
      "contracts/utils/Hasher.sol",
      [],
      deployUtils
    );
    deployUtils.addresses["Hasher"] = hasher.address;
    console.log(deployUtils.addresses);


    const capacitorFactory: Contract = await getOrDeploy(
      "CapacitorFactory",
      "contracts/CapacitorFactory.sol",
      [socketOwner],
      deployUtils
    );
    deployUtils.addresses["CapacitorFactory"] = capacitorFactory.address;
    console.log(deployUtils.addresses);


    const gasPriceOracle: Contract = await getOrDeploy(
      "GasPriceOracle",
      "contracts/GasPriceOracle.sol",
      [socketOwner, chainSlugs[network]],
      deployUtils
    );
    deployUtils.addresses["GasPriceOracle"] = gasPriceOracle.address;
    console.log(deployUtils.addresses);


    const executionManager: Contract = await getOrDeploy(
      "ExecutionManager",
      "contracts/ExecutionManager.sol",
      [gasPriceOracle.address, socketOwner],
      deployUtils
    );
    deployUtils.addresses["ExecutionManager"] = executionManager.address;
    console.log(deployUtils.addresses);


    const transmitManager: Contract = await getOrDeploy(
      "TransmitManager",
      "contracts/TransmitManager.sol",
      [
        signatureVerifier.address,
        gasPriceOracle.address,
        socketOwner,
        chainSlugs[network],
        sealGasLimit[networkToChainSlug[network]],
      ],
      deployUtils
    );
    deployUtils.addresses["TransmitManager"] = transmitManager.address;
    console.log(deployUtils.addresses);


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
      ],
      deployUtils
    );
    deployUtils.addresses["Socket"] = socket.address;
    console.log(deployUtils.addresses);


    // switchboards deploy
    const result = await deploySwitchboards(
      network,
      socketSigner,
      deployedAddresses,
      verificationDetails,
      currentMode
    );

    deployUtils.addresses = result["sourceConfig"];
    console.log(deployUtils.addresses);

    verificationDetails = result["verificationDetails"];

    const socketBatcher: Contract = await getOrDeploy(
      "SocketBatcher",
      "contracts/socket/SocketBatcher.sol",
      [socketOwner],
      deployUtils
    );
    deployUtils.addresses["SocketBatcher"] = socketBatcher.address;
    console.log(deployUtils.addresses);


    // plug deployments
    const counter: Contract = await getOrDeploy(
      "Counter",
      "contracts/examples/Counter.sol",
      [socket.address],
      deployUtils
    );
    deployUtils.addresses["Counter"] = counter.address;
    console.log(deployUtils.addresses);

    allDeployed = true;
    console.log("Contracts deployed!");
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }

  await storeAddresses(deployUtils.addresses, deployUtils.currentChainSlug, deployUtils.mode);
  return { verificationDetails, allDeployed, deployedAddresses };
};

async function getOrDeploy(
  contractName: string,
  path: string,
  args: any[],
  deployUtils
): Promise<Contract> {
  let contract: Contract;
  if (!deployUtils.addresses[contractName]) {
    contract = await deployContractWithArgs(
      contractName,
      args,
      deployUtils.signer
    );
    verificationDetails.push([contract.address, contractName, path, args]);
  } else {
    contract = await getInstance(
      contractName,
      deployUtils.addresses[contractName]
    );
  }

  console.log(
    `${contractName} deployed on ${deployUtils.currentChainSlug} for ${deployUtils.mode} at address ${contract.address}`
  );
  return contract;
}
