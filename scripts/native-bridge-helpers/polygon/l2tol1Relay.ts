import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { use, POSClient } from "@maticnetwork/maticjs";
import { Web3ClientPlugin } from "@maticnetwork/maticjs-ethers";
import { providers, Wallet } from "ethers";
import {
  Provider,
  TransactionRequest,
  TransactionResponse,
} from "@ethersproject/abstract-provider";
import { Signer } from "@ethersproject/abstract-signer";
import { Bytes } from "@ethersproject/bytes";
import { Deferrable } from "@ethersproject/properties";
import { Transaction } from "@ethersproject/transactions";
import axios from "axios";

use(Web3ClientPlugin);

type ProviderWithWrapTransaction = Provider & {
  _wrapTransaction(tx: Transaction, hash?: string): TransactionResponse;
};

const axiosPost = async (url: string, data: any, config: object = {}) => {
  try {
    let response = await axios.post(url, data, config);
    return { success: true, ...response.data };
  } catch (error: any) {
    console.log("status : ", error?.response?.status);
    return { success: false, ...error?.response?.data };
  }
};

export class SocketRelaySigner extends Signer {
  constructor(
    readonly provider: Provider,
    readonly relayUrl: string,
    readonly sequential: boolean = false
  ) {
    super();
  }

  public async getAddress(): Promise<string> {
    // some random address
    return "0x5367Efc17020Aa1CF0943bA7eD17f1D3e4c7d7EE";
  }
  public async signMessage(message: string | Bytes): Promise<string> {
    throw new Error(" signMessage not Implemented");
  }
  public connect(provider: Provider): Signer {
    return new SocketRelaySigner(provider, this.relayUrl, this.sequential);
  }
  public async signTransaction(
    transaction: Deferrable<TransactionRequest>
  ): Promise<string> {
    throw new Error(" signTransaction not Implemented");
  }
  public async sendTransaction(
    transaction: Deferrable<TransactionRequest>
  ): Promise<TransactionResponse> {
    let payload = {
      chainId: (await this.provider.getNetwork()).chainId,
      sequential: this.sequential,
      ...transaction,
    };
    console.log("sendTransaction in signer: ", payload);
    let result = await axiosPost(this.relayUrl, payload);
    if (!result.success) throw result;
    let tx = result?.data as Transaction;
    return (this.provider as ProviderWithWrapTransaction)._wrapTransaction(tx);
  }
}

import { getJsonRpcUrl } from "../../constants";
import { deployedAddressPath, getInstance } from "../../deploy/utils";
import { mode } from "../../deploy/config";
import { chainKeyToSlug, IntegrationTypes } from "../../../src";

// get providers for source and destination
const privateKey = process.env.SOCKET_SIGNER_KEY!;
const sealTxHash = "";

const localChain = "polygon-mainnet";
const remoteChain = "mainnet";

const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(localChain));
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(remoteChain));
const l1Wallet = new Wallet(privateKey, l2Provider);
const l2Wallet = new Wallet(privateKey, l1Provider);
const l1Signer = new SocketRelaySigner(
  l1Provider,
  "https://9u4hhxgtyi.execute-api.us-east-1.amazonaws.com/dev/v1/relayTx"
);
const l2Signer = new SocketRelaySigner(
  l2Provider,
  "https://9u4hhxgtyi.execute-api.us-east-1.amazonaws.com/dev/v1/relayTx"
);

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath(mode))) {
      throw new Error("addresses.json not found");
    }
    const addresses = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );

    if (
      !addresses[chainKeyToSlug[localChain]] ||
      !addresses[chainKeyToSlug[remoteChain]]
    ) {
      throw new Error("Deployed Addresses not found");
    }
    const l1Config = addresses[chainKeyToSlug[remoteChain]];
    const ABI = ["function receiveMessage(bytes memory receivePacketProof)"];

    // get socket contracts for both chains
    // counter l1, counter l2, seal, execute
    const l1Switchboard = (
      await getInstance(
        "PolygonL1Switchboard",
        l1Config["integrations"][chainKeyToSlug[localChain]][
          IntegrationTypes.native
        ]["switchboard"]
      )
    ).connect(l1Signer);

    const posClient = new POSClient();
    await posClient.init({
      network: "mainnet",
      version: "v1",
      parent: {
        provider: l1Signer, //new HDWalletProvider(privateKey, parentRPC),
        defaultConfig: {
          from: "0x5367Efc17020Aa1CF0943bA7eD17f1D3e4c7d7EE",
        },
      },
      child: {
        provider: l2Signer, //new HDWalletProvider(privateKey, childRPC),
        defaultConfig: {
          from: "0x5367Efc17020Aa1CF0943bA7eD17f1D3e4c7d7EE",
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

    console.log("proof: ", proof);
    const tx = await l1Switchboard.receiveMessage(proof);
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
