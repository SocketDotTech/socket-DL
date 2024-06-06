import { providers, Wallet } from "ethers";
import { CrossChainMessenger, MessageStatus } from "@eth-optimism/sdk";
import { getJsonRpcUrl } from "../../constants";
import { HardhatChainName, ChainId } from "../../../src";

// get providers for source and destination
const l1ChainId = ChainId.SEPOLIA;
const l2ChainId = ChainId.OPTIMISM_SEPOLIA;

const walletPrivateKey = process.env.SOCKET_SIGNER_KEY!;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l1ChainId));
const l1Wallet = new Wallet(walletPrivateKey, l1Provider);

const sealTxHash = "";

export const main = async () => {
  const crossChainMessenger = new CrossChainMessenger({
    l1ChainId,
    l2ChainId,
    l1SignerOrProvider: l1Wallet,
    l2SignerOrProvider: new providers.JsonRpcProvider(getJsonRpcUrl(l2ChainId)),
  });

  const status = await crossChainMessenger.getMessageStatus(sealTxHash);

  if (MessageStatus.READY_TO_PROVE === status) {
    const tx = await crossChainMessenger.proveMessage(sealTxHash);
    await tx.wait();
    console.log("Message proved", tx.hash);
  } else if (MessageStatus.READY_FOR_RELAY === status) {
    const tx = await crossChainMessenger.finalizeMessage(sealTxHash);
    await tx.wait();
    console.log("Message finalized", tx.hash);
  } else if (MessageStatus.RELAYED === status) {
    console.log("Message relayed");
  } else {
    console.log(`Message is in ${status} status`);
  }
};

// npx ts-node scripts/native-bridge-helpers/optimism/l2tol1Relay.ts
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
