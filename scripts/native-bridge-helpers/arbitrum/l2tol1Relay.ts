import fs from "fs";
import { providers, Wallet } from "ethers";
import { deployedAddressPath } from "../../deploy/utils";
import { chainIds, getJsonRpcUrl } from "../../constants";
import { L2ToL1MessageStatus, L2TransactionReceipt } from "@arbitrum/sdk";

// https://goerli.arbiscan.io/txsExit to check message status
const l1Chain = "goerli";
const l2Chain = "arbitrum-goerli";
const sealTxHash =
  "0x0113020a1e3b9f814a78791b9719bf583bb0f25075cde1e754af99f1dcf137a7";

const walletPrivateKey = process.env.DEVNET_PRIVKEY;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l1Chain));
const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l2Chain));

const l1Wallet = new Wallet(walletPrivateKey, l1Provider);

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath)) {
      throw new Error("addresses.json not found");
    }
    const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));

    if (!addresses[chainIds[l1Chain]] || !addresses[chainIds[l2Chain]]) {
      throw new Error("Deployed Addresses not found");
    }

    const receipt = await l2Provider.getTransactionReceipt(sealTxHash);
    const l2Receipt = new L2TransactionReceipt(receipt);

    /**
     * Note that in principle, a single transaction could trigger any number of outgoing messages; the common case will be there's only one.
     * For the sake of this script, we assume there's only one / just grad the first one.
     */
    const messages = await l2Receipt.getL2ToL1Messages(l1Wallet);
    const l2ToL1Msg = messages[0];

    const status = await l2ToL1Msg.status(l2Provider);
    /**
     * Check if already executed
     */
    if (status == L2ToL1MessageStatus.EXECUTED) {
      console.log(`Message already executed! Nothing else to do here`);
      process.exit(1);
    }

    /**
     * before we try to execute out message, we need to make sure the l2 block it's included in is confirmed! (It can only be confirmed after the dispute period; Arbitrum is an optimistic rollup after-all)
     * waitUntilReadyToExecute() waits until the item outbox entry exists
     */
    const timeToWaitMs = 1000 * 60;
    console.log(
      "Waiting for the outbox entry to be created. This only happens when the L2 block is confirmed on L1, ~1 week after it's creation."
    );
    await l2ToL1Msg.waitUntilReadyToExecute(l2Provider, timeToWaitMs);
    console.log("Outbox entry exists! Trying to execute now");

    /**
     * Now that its confirmed and not executed, we can execute our message in its outbox entry.
     */
    const res = await l2ToL1Msg.execute(l2Provider);
    const rec = await res.wait();
    console.log("Done! Your transaction is executed", rec);
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