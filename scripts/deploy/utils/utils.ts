import { Wallet, utils } from "ethers";
import { network, ethers, run, artifacts } from "hardhat";

import { ContractFactory, Contract } from "ethers";
import { Address } from "hardhat-deploy/dist/types";
import path from "path";
import fs from "fs";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  DeploymentMode,
} from "../../../src";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { overrides } from "../config";
import { isKinto, deployOnKinto } from "./kinto/kinto";

export const deploymentsPath = path.join(__dirname, `/../../../deployments/`);

export const deployedAddressPath = (mode: DeploymentMode) =>
  deploymentsPath + `${mode}_addresses.json`;

export const getRoleHash = (role: string) =>
  ethers.utils.keccak256(ethers.utils.toUtf8Bytes(role)).toString();

export const getChainRoleHash = (role: string, chainSlug: number) =>
  ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "uint32"],
      [getRoleHash(role), chainSlug]
    )
  );

export interface DeployParams {
  addresses: ChainSocketAddresses;
  mode: DeploymentMode;
  signer: SignerWithAddress | Wallet;
  currentChainSlug: number;
}

export const getOrDeploy = async (
  contractName: string,
  path: string,
  args: any[],
  deployUtils: DeployParams
): Promise<Contract> => {
  if (!deployUtils || !deployUtils.addresses)
    throw new Error("No addresses found");

  let contract: Contract;
  if (!deployUtils.addresses[contractName]) {
    contract = await deployContractWithArgs(
      path + `:${contractName}`,
      args,
      deployUtils.signer
    );

    console.log(
      `${contractName} deployed on ${deployUtils.currentChainSlug} for ${deployUtils.mode} at address ${contract.address}`
    );

    await storeVerificationParams(
      [contract.address, contractName, path, args],
      deployUtils.currentChainSlug,
      deployUtils.mode
    );
  } else {
    contract = await getInstance(
      contractName,
      deployUtils.addresses[contractName]
    );
    console.log(
      `${contractName} found on ${deployUtils.currentChainSlug} for ${deployUtils.mode} at address ${contract.address}`
    );
  }

  return contract;
};

export async function deployContractWithArgs(
  contractName: string,
  args: Array<any>,
  signer: SignerWithAddress | Wallet
) {
  try {
    let contract: Contract;
    if (isKinto(await signer.getChainId())) {
      contract = await deployOnKinto(
        process.env.SOCKET_OWNER_ADDRESS,
        contractName,
        args,
        process.env.SOCKET_SIGNER_KEY
      );
    } else {
      const Contract: ContractFactory = await ethers.getContractFactory(
        contractName
      );
      // gasLimit is set to undefined to not use the value set in overrides
      contract = await Contract.connect(signer).deploy(...args, {
        ...overrides(await signer.getChainId()),
      });
    }
    await contract.deployed();
    return contract;
  } catch (error) {
    throw error;
  }
}

export const verify = async (
  address: string,
  contractName: string,
  path: string,
  args: any[]
): Promise<boolean> => {
  try {
    const chainSlug = await getChainSlug();
    if (chainSlug === 31337) return true;

    await run("verify:verify", {
      address,
      contract: `${path}:${contractName}`,
      constructorArguments: args,
    });
    return true;
  } catch (error) {
    console.log("Error during verification", error);
  }

  return false;
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

export const getInstance = async (
  contractName: string,
  address: Address
): Promise<Contract> => {
  const artifact = await artifacts.readArtifact(contractName);
  return new ethers.Contract(address, artifact.abi);
};

export const getChainSlug = async (): Promise<number> => {
  if (network.config.chainId === undefined)
    throw new Error("chain id not found");
  return Number(network.config.chainId);
};

export const integrationType = (integrationName: string) =>
  ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(["string"], [integrationName])
  );

export const storeAddresses = async (
  addresses: ChainSocketAddresses,
  chainSlug: ChainSlug,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath, { recursive: true });
  }

  const addressesPath = deploymentsPath + `${mode}_addresses.json`;
  const outputExists = fs.existsSync(addressesPath);
  let deploymentAddresses: DeploymentAddresses = {};
  if (outputExists) {
    const deploymentAddressesString = fs.readFileSync(addressesPath, "utf-8");
    deploymentAddresses = JSON.parse(deploymentAddressesString);
  }

  deploymentAddresses[chainSlug] = addresses;
  fs.writeFileSync(
    addressesPath,
    JSON.stringify(deploymentAddresses, null, 2) + "\n"
  );
};

export const storeAllAddresses = async (
  addresses: DeploymentAddresses,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath, { recursive: true });
  }

  const addressesPath = deploymentsPath + `${mode}_addresses.json`;
  fs.writeFileSync(addressesPath, JSON.stringify(addresses, null, 2) + "\n");
};

export const storeVerificationParams = async (
  verificationDetail: any[],
  chainSlug: ChainSlug,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath);
  }
  const verificationPath = deploymentsPath + `${mode}_verification.json`;
  const outputExists = fs.existsSync(verificationPath);
  let verificationDetails: object = {};
  if (outputExists) {
    const verificationDetailsString = fs.readFileSync(
      verificationPath,
      "utf-8"
    );
    verificationDetails = JSON.parse(verificationDetailsString);
  }

  if (!verificationDetails[chainSlug]) verificationDetails[chainSlug] = [];
  verificationDetails[chainSlug] = [
    verificationDetail,
    ...verificationDetails[chainSlug],
  ];

  fs.writeFileSync(
    verificationPath,
    JSON.stringify(verificationDetails, null, 2) + "\n"
  );
};

export const getChainSlugsFromDeployedAddresses = async (
  mode = DeploymentMode.DEV
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath);
  }
  const addressesPath = deploymentsPath + `${mode}_addresses.json`;

  const outputExists = fs.existsSync(addressesPath);
  let deploymentAddresses: DeploymentAddresses = {};
  if (outputExists) {
    const deploymentAddressesString = fs.readFileSync(addressesPath, "utf-8");
    deploymentAddresses = JSON.parse(deploymentAddressesString);

    return Object.keys(deploymentAddresses);
  }
};

export const getRelayUrl = async (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.SURGE:
      return process.env.RELAYER_URL_SURGE;
    case DeploymentMode.PROD:
      return process.env.RELAYER_URL_PROD;
    default:
      return process.env.RELAYER_URL_DEV;
  }
};

export const getRelayAPIKEY = (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.SURGE:
      return process.env.RELAYER_API_KEY_SURGE;
    case DeploymentMode.PROD:
      return process.env.RELAYER_API_KEY_PROD;
    default:
      return process.env.RELAYER_API_KEY_DEV;
  }
};

export const getAddresses = async (
  chainSlug: ChainSlug,
  mode = DeploymentMode.DEV
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath);
  }

  const addressesPath = deploymentsPath + `${mode}_addresses.json`;
  const outputExists = fs.existsSync(addressesPath);
  let deploymentAddresses: DeploymentAddresses = {};
  if (outputExists) {
    const deploymentAddressesString = fs.readFileSync(addressesPath, "utf-8");
    deploymentAddresses = JSON.parse(deploymentAddressesString);
  }

  return deploymentAddresses[chainSlug];
};

export const createObj = function (
  obj: ChainSocketAddresses,
  keys: string[],
  value: any
): ChainSocketAddresses {
  if (keys.length === 1) {
    obj[keys[0]] = value;
  } else {
    const key = keys.shift();
    if (key === undefined) return obj;
    obj[key] = createObj(
      typeof obj[key] === "undefined" ? {} : obj[key],
      keys,
      value
    );
  }
  return obj;
};

export const toLowerCase = (str?: string) => {
  if (!str) return "";
  return str.toLowerCase();
};

export function getChainSlugFromId(chainId: number) {
  const MAX_UINT_32 = 4294967295;
  if (chainId < MAX_UINT_32) return chainId;

  // avoid conflict for now
  return parseInt(utils.id(chainId.toString()).substring(0, 10));
}
