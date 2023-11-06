import { config as dotenvConfig } from "dotenv";

import { constants, providers, Wallet } from "ethers";
import { CrossChainMessenger, MessageStatus } from "@eth-optimism/sdk";
import { getJsonRpcUrl } from "../../constants";
import { ChainId } from "../../../src";
import { resolve } from "path";
import axios from "axios";

const dotenvConfigPath: string =
  process.env.DOTENV_CONFIG_PATH || "../../../.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// get providers for source and destination
const l1Chain = ChainId.SEPOLIA;
const l2Chain = ChainId.LYRA_TESTNET;
const configLink =
  "https://api.conduit.xyz/file/getOptimismContractsJSON?network=fc538f39-aed2-48aa-a4ff-d733dd3be1e6&organization=9353f461-a1a4-4fb4-80de-90587a32f4b1";
const initTxHash =
  "0x373611163c75ca063aae79fc7a8ef4a9d8e66603cc92997cbbcd2a18cbbcde37";

const walletPrivateKey = process.env.SOCKET_SIGNER_KEY!;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l1Chain));
const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l2Chain));

const l1Wallet = new Wallet(walletPrivateKey, l1Provider);

export const main = async () => {
  const { data } = await axios.get(configLink);
  const crossChainMessenger = new CrossChainMessenger({
    contracts: {
      l1: {
        StateCommitmentChain: constants.AddressZero,
        CanonicalTransactionChain: constants.AddressZero,
        BondManager: constants.AddressZero,
        AddressManager: data["AddressManager"],
        L1CrossDomainMessenger: data["L1CrossDomainMessengerProxy"],
        L1StandardBridge: data["L1StandardBridgeProxy"],
        OptimismPortal: data["OptimismPortalProxy"],
        L2OutputOracle: data["L2OutputOracleProxy"],
      },
    },
    l1ChainId: l1Chain,
    l2ChainId: l2Chain,
    l1SignerOrProvider: l1Wallet,
    l2SignerOrProvider: l2Provider,
    bedrock: true,
  });

  const status = await crossChainMessenger.getMessageStatus(initTxHash);

  if (MessageStatus.READY_TO_PROVE === status) {
    console.log(`Message is ready to prove`);
    const tx = await crossChainMessenger.proveMessage(initTxHash);
    await tx.wait();
    console.log("Message proved", tx.hash);
  } else if (MessageStatus.READY_FOR_RELAY === status) {
    console.log(`Message is ready for relay`);
    const tx = await crossChainMessenger.finalizeMessage(initTxHash);
    await tx.wait();
    console.log("Message finalized", tx.hash);
  } else if (MessageStatus.RELAYED === status) {
    console.log("Message relayed");
  } else {
    console.log(`status: ${status}`);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
