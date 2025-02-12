import { Wallet, utils } from "ethers";
import { network, ethers, run } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { Address } from "hardhat-deploy/dist/types";
import path from "path";
import fs from "fs";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  DeploymentMode,
  zkStackChain,
} from "../../../src";
import { overrides } from "../config/config";
import { VerifyArgs } from "../verify";
import { SocketSigner } from "@socket.tech/dl-common";
import { chainIdToSlug, getZkWallet } from "../../constants";
import { Deployer } from "@matterlabs/hardhat-zksync";
import * as hre from "hardhat";

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
  signer: SocketSigner;
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
    contract = (
      await getInstance(contractName, deployUtils.addresses[contractName])
    ).connect(deployUtils.signer);
    console.log(
      `${contractName} found on ${deployUtils.currentChainSlug} for ${deployUtils.mode} at address ${contract.address}`
    );
  }

  return contract;
};

export async function deployContractWithArgs(
  contractName: string,
  args: Array<any>,
  signer: SocketSigner
): Promise<Contract> {
  // this log line lets deployments on bera chain work
  // rolling with it since its needed fast
  // kekekekekekekekek
  console.log("deploying contract", contractName, args);
  try {
    const chainId = (await signer.provider.getNetwork()).chainId;
    const chainSlug = chainIdToSlug(chainId);

    if (zkStackChain.includes(chainSlug)) {
      const wallet = getZkWallet(chainSlug);
      const deployer = new Deployer(hre, wallet);
      const artifact = await deployer
        .loadArtifact(contractName)
        .catch((error) => {
          if (
            error?.message?.includes(
              `Artifact for contract "${contractName}" not found.`
            )
          ) {
            console.error(error.message);
            throw `⛔️ Please make sure you have compiled your contracts or specified the correct contract name!`;
          } else {
            throw error;
          }
        });
      const zkContract = await deployer.deploy(artifact, args);
      const address = await zkContract.getAddress();
      const contractFactory: ContractFactory = await ethers.getContractFactory(
        contractName
      );
      const instance = contractFactory.attach(address);
      return { ...instance, address };
    } else {
      const contractFactory: ContractFactory = await ethers.getContractFactory(
        contractName,
        signer
      );
      const contract: Contract = await contractFactory.deploy(...args, {
        ...(await overrides(chainSlug)),
      });
      await contract.deployed();
      return contract;
    }
  } catch (error) {
    console.log(error);
    process.exit(1);
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
    if (error.toString().includes("Contract source code already verified"))
      return true;
  }

  return false;
};

export const getInstance = async (
  contractName: string,
  address: Address
): Promise<Contract> => {
  const artifact = await hre.artifacts.readArtifact(contractName);
  const c = new Contract(address, artifact.abi);
  return c;
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

export const storeUnVerifiedParams = async (
  verifyParams: VerifyArgs[],
  chainSlug: ChainSlug,
  mode: DeploymentMode
) => {
  if (!fs.existsSync(deploymentsPath)) {
    await fs.promises.mkdir(deploymentsPath, { recursive: true });
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

  verificationDetails[chainSlug] = verifyParams;
  fs.writeFileSync(
    verificationPath,
    JSON.stringify(verificationDetails, null, 2) + "\n"
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

export const getAPIBaseURL = (mode: DeploymentMode) => {
  switch (mode) {
    case DeploymentMode.PROD:
      return process.env.DL_API_PROD_URL;
    default:
      return process.env.DL_API_DEV_URL;
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
