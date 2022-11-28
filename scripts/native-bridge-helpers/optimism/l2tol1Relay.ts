import { providers, Wallet } from "ethers";
import { CrossChainMessenger, MessageStatus } from "@eth-optimism/sdk";
import { getJsonRpcUrl } from "../../constants";

// get providers for source and destination
const localChain = "optimism-goerli";
const remoteChain = "goerli";

const walletPrivateKey = process.env.DEVNET_PRIVKEY;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(localChain));
const l1Wallet = new Wallet(walletPrivateKey, l1Provider);

const sealTxHash = "";

export const main = async () => {
  const crossChainMessenger = new CrossChainMessenger({
    l1ChainId: 5,
    l2ChainId: 420,
    l1SignerOrProvider: l1Wallet,
    l2SignerOrProvider: new providers.JsonRpcProvider(
      getJsonRpcUrl(remoteChain)
    ),
  });

  const status = await crossChainMessenger.getMessageStatus(sealTxHash);

  if (MessageStatus.READY_FOR_RELAY === status) {
    const tx = await crossChainMessenger.finalizeMessage(sealTxHash);
    await tx.wait();
  } else {
    console.log("Message not confirmed yet!");
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
