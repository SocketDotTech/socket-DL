import { StaticJsonRpcProvider } from "@ethersproject/providers";
import { utils } from "ethers";
import prompts from "prompts";

import { updateSDK, buildEnvFile, updateConfig } from "./utils";
import {
  ChainSlug,
  DeploymentMode,
  MainnetIds,
  TestnetIds,
} from "../../../../src";
import {
  executorAddresses,
  transmitterAddresses,
  watcherAddresses,
} from "../../config";
import { RoleOwners } from "../../../constants";

export async function writeConfigs() {
  const response = await prompts([
    {
      name: "rpc",
      type: "text",
      message: "Enter rpc url",
      validate: validateRpc,
    },
    {
      name: "chainName",
      type: "text",
      message: "Enter chain name (without spaces, use - instead of spaces)",
    },
    {
      name: "isMainnet",
      type: "toggle",
      message: "Is it mainnet or testnet?",
    },
  ]);

  const chainOptions = response.isMainnet ? MainnetIds : TestnetIds;
  const choices = chainOptions.map((chain) => ({
    title: chain.toString(),
    value: chain,
  }));

  const configResponse = await prompts([
    {
      name: "siblings",
      type: "multiselect",
      message: "Select chains you want to use as message destination",
      choices,
    },
    {
      name: "owner",
      type: "text",
      message: "Enter owner address",
      validate: validateAddress,
    },
    {
      name: "transmitter",
      type: "text",
      message:
        "Enter transmitter address if you want to transmit, else leave blank",
      validate: validateAddress,
    },
    {
      name: "executor",
      type: "text",
      message:
        "Enter executor address if you want to execute, else leave blank",
      validate: validateAddress,
    },
    {
      name: "watcher",
      type: "text",
      message: "Enter watcher address if you want to attest, else leave blank",
      validate: validateAddress,
    },
    {
      name: "feeUpdater",
      type: "text",
      message:
        "Enter fee updater address if you want to run oracle, else leave blank",
      validate: validateAddress,
    },
    {
      name: "pk",
      type: "text",
      message:
        "Enter deployer private key (can be left blank and added to env separately)",
    },
    {
      name: "timeout",
      type: "text",
      message:
        "Enter timeout, leave blank if you want to keep it default (2 hrs)",
    },
    {
      name: "msgValueMaxThreshold",
      type: "text",
      message:
        "Enter max msg value transfer limit, leave blank if you want to keep it default (0.01 ETH)",
    },
    {
      name: "type",
      type: "text",
      message:
        "Enter transaction type supported, leave blank if you want it to be picked from RPC",
    },
    {
      name: "gasLimit",
      type: "text",
      message:
        "Enter max gas limit, leave blank if you want it to be picked from RPC",
    },
    {
      name: "gasPrice",
      type: "text",
      message:
        "Enter gas price, leave blank if you want it to be picked from RPC",
    },
  ]);

  // update types and enums
  const chainId = await getChainId(response.rpc);
  await updateSDK(response.chainName, chainId, response.isMainnet);

  // update env and config
  const roleOwners: RoleOwners = {
    ownerAddress: "",
    executorAddress: "",
    transmitterAddress: "",
    watcherAddress: "",
    feeUpdaterAddress: "",
  };

  if (configResponse.owner) {
    roleOwners.ownerAddress = configResponse.owner;
  } else roleOwners.ownerAddress = transmitterAddresses[DeploymentMode.PROD];

  if (configResponse.transmitter) {
    roleOwners.transmitterAddress = configResponse.transmitter;
  } else
    roleOwners.transmitterAddress = transmitterAddresses[DeploymentMode.PROD];

  if (configResponse.executor) {
    roleOwners.executorAddress = configResponse.executor;
  } else roleOwners.executorAddress = executorAddresses[DeploymentMode.PROD];

  if (configResponse.watcher) {
    roleOwners.watcherAddress = configResponse.watcher;
  } else roleOwners.watcherAddress = watcherAddresses[DeploymentMode.PROD];

  if (configResponse.feeUpdater) {
    roleOwners.feeUpdaterAddress = configResponse.feeUpdater;
  } else
    roleOwners.feeUpdaterAddress = transmitterAddresses[DeploymentMode.PROD];

  // write chain config and env for NEW_RPC and SOCKET_SIGNER_KEY
  const config = {
    roleOwners,
    siblings: configResponse.siblings,
    overrides: {},
  };

  if (configResponse.timeout) config["timeout"] = configResponse.timeout;
  if (configResponse.msgValueMaxThreshold)
    config["msgValueMaxThreshold"] = configResponse.msgValueMaxThreshold;
  if (configResponse.type) config["overrides"]["type"] = configResponse.type;
  if (configResponse.gasLimit)
    config["overrides"]["gasLimit"] = configResponse.gasLimit;
  if (configResponse.gasPrice)
    config["overrides"]["gasPrice"] = configResponse.gasPrice;

  await updateConfig(chainId as ChainSlug, config);
  await buildEnvFile(
    response.rpc,
    roleOwners.ownerAddress,
    configResponse.pk ?? ""
  );
}

const validateRpc = async (rpcUrl: string) => {
  if (!rpcUrl) {
    return "Invalid RPC";
  }
  return getChainId(rpcUrl)
    .then((a) => true)
    .catch((e) => `Invalid RPC: ${e}`);
};

const validateAddress = (address: string) => {
  if (!address || address.length === 0) return true;
  return utils.isAddress(address);
};

const getChainId = async (rpcUrl: string) => {
  const provider = new StaticJsonRpcProvider(rpcUrl);
  const network = await provider.getNetwork();
  return network.chainId;
};
