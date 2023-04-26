import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { use, POSClient } from "@maticnetwork/maticjs";
import { Web3ClientPlugin } from "@maticnetwork/maticjs-ethers";
import { providers, Wallet } from "ethers";
use(Web3ClientPlugin);

import { DeploymentMode, chainSlugs, getJsonRpcUrl } from "../../constants";
import { deployedAddressPath, getInstance } from "../../deploy/utils";

// get providers for source and destination
const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;
const privateKey = process.env.SOCKET_SIGNER_KEY;
const sealTxHash = "";

const localChain = "polygon-mumbai";
const remoteChain = "goerli";

const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(localChain));
const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(remoteChain));
const l1Wallet = new Wallet(privateKey, l1Provider);
const l2Wallet = new Wallet(privateKey, l2Provider);

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath(mode))) {
      throw new Error("addresses.json not found");
    }
    const addresses = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );

    if (
      !addresses[chainSlugs[localChain]] ||
      !addresses[chainSlugs[remoteChain]]
    ) {
      throw new Error("Deployed Addresses not found");
    }
    const l2Config = addresses[chainSlugs[remoteChain]];

    // get socket contracts for both chains
    // counter l1, counter l2, seal, execute
    const contracts = contractNames("", localChain, remoteChain);
    const l2Notary = (
      await getInstance(
        contracts.notary,
        l2Config[contracts.notary][chainSlugs[remoteChain]]
      )
    ).connect(l2Wallet);

    const posClient = new POSClient();
    await posClient.init({
      network: "testnet",
      version: "mumbai",
      parent: {
        provider: l2Wallet, //new HDWalletProvider(privateKey, parentRPC),
        defaultConfig: {
          from: l2Wallet.address,
        },
      },
      child: {
        provider: l1Wallet, //new HDWalletProvider(privateKey, childRPC),
        defaultConfig: {
          from: l1Wallet.address,
        },
      },
    });

    const isCheckPointed = await posClient.exitUtil.isCheckPointed(sealTxHash);

    if (!isCheckPointed) {
      console.log("Message not confirmed yet, try after some time");
      return;
    }

    const proof = await posClient.exitUtil.buildPayloadForExit(
      sealTxHash,
      "0x8c5261668696ce22758910d05bab8f186d6eb247ceac2af2e82c7dc17669b036",
      false
    );

    const tx = await l2Notary.receiveMessage(proof);
    await tx.wait();
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
