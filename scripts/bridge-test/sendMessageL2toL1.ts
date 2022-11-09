import fs from "fs";
import { Contract, providers, Wallet } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { L2TransactionReceipt, L2ToL1MessageStatus } from '@arbitrum/sdk'

import { getInstance, deployedAddressPath } from "../deploy/utils";
import { packPacketId } from "../deploy/scripts/packetId";

// get providers for source and destination
const walletPrivateKey = process.env.DEVNET_PRIVKEY
const l1Provider = new providers.JsonRpcProvider(process.env.L1RPC)
const l2Provider = new providers.JsonRpcProvider(process.env.L2RPC)

const amount = 100
const msgGasLimit = 150000
const proof = "0x0000000000000000000000000000000000000000000000000000000000000000"
const l1ChainId = 5;
const l2ChainId = 421613;

const l1Wallet = new Wallet(walletPrivateKey, l1Provider)
const l2Wallet = new Wallet(walletPrivateKey, l2Provider)

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath + l1ChainId + ".json") || !fs.existsSync(deployedAddressPath + l2ChainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const l1Config: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + l1ChainId + ".json", "utf-8"));
    const l2Config: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + l2ChainId + ".json", "utf-8"))

    // get socket contracts for both chains
    // counter l1, counter l2, seal, execute
    const l1Counter: Contract = (await getInstance("Counter", l1Config["counter"])).connect(l1Wallet);
    const l2Counter: Contract = (await getInstance("Counter", l2Config["counter"])).connect(l2Wallet);

    const l2Notary: Contract = (await getInstance("AdminNotary", l2Config["notary"])).connect(l2Wallet);
    const l1Socket: Contract = (await getInstance("Socket", l1Config["socket"])).connect(l1Wallet);

    const arbitrumAccumL2: Contract = (await getInstance("ArbitrumL2Accum", l2Config["arbitrumAccum-5"])).connect(l2Wallet);

    // outbound
    const outboundTx = await l2Counter.remoteAddOperation(l1ChainId, amount, msgGasLimit);
    const outboundTxReceipt = await outboundTx.wait()
    console.log(outboundTxReceipt.events);

    // seal
    const { packetId, newRootHash } = arbitrumAccumL2.interface.decodeEventLog("MessageAdded", outboundTxReceipt.events[1].data)
    const { payload, msgId } = l1Socket.interface.decodeEventLog("MessageTransmitted", outboundTxReceipt.events[2].data)
    const packedPacketId = packPacketId(l2ChainId, arbitrumAccumL2.address, packetId)

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["uint256", "uint256", "bytes32"],
        [l1ChainId, packedPacketId, newRootHash]
      )
    );
    const signature = await l2Wallet.signMessage(arrayify(digest));

    console.log(`Sealing with params ${arbitrumAccumL2.address}, ${signature}, ${packedPacketId}, ${newRootHash}, ${packetId}`);
    const sealTx = await l2Notary.seal(arbitrumAccumL2.address, [], signature);
    const sealTxReceipt = await sealTx.wait()

    // wait for msg to arrive on l2
    console.log(
      `Seal txn confirmed on L2! 🙌 ${sealTxReceipt.transactionHash}`
    )

    const receipt = await l2Provider.getTransactionReceipt("0x4a0a23e6137cad9d2e57f174e04588db78612b8736100b5bcfa5b6aa726f16da")
    const l2Receipt = new L2TransactionReceipt(receipt)

    /**
    * Note that in principle, a single transaction could trigger any number of outgoing messages; the common case will be there's only one.
    * For the sake of this script, we assume there's only one / just grad the first one.
    */
    const messages = await l2Receipt.getL2ToL1Messages(l1Wallet, l2Provider)
    console.log(messages);
    const l2ToL1Msg = messages[0]
    /**
   * Check if already executed
   */
    if ((await l2ToL1Msg.status(l2Provider)) == L2ToL1MessageStatus.EXECUTED) {
      console.log(`Message already executed! Nothing else to do here`)
      process.exit(1)
    }

    /**
       * before we try to execute out message, we need to make sure the l2 block it's included in is confirmed! (It can only be confirmed after the dispute period; Arbitrum is an optimistic rollup after-all)
       * waitUntilReadyToExecute() waits until the item outbox entry exists
       */
    const timeToWaitMs = 1000 * 60
    console.log(
      "Waiting for the outbox entry to be created. This only happens when the L2 block is confirmed on L1, ~1 week after it's creation."
    )
    await l2ToL1Msg.waitUntilReadyToExecute(l2Provider, timeToWaitMs)
    console.log('Outbox entry exists! Trying to execute now')

    /**
     * Now that its confirmed and not executed, we can execute our message in its outbox entry.
     */
    const res = await l2ToL1Msg.execute(l2Provider)
    const rec = await res.wait()
    console.log('Done! Your transaction is executed', rec)

    // execute msg
    const executeTx = await l1Socket.execute(
      msgGasLimit,
      msgId,
      l1Config["counter"],
      payload,
      [
        l2ChainId,
        packedPacketId,
        proof
      ]
    )
    await executeTx.wait()

    const counter = await l1Counter.counter();
    console.log(`Counter updated at destination ${counter}`);
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