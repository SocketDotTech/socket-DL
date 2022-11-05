import fs from "fs";
import { getInstance, deployedAddressPath } from "../deploy/utils";
import { Contract, providers, Wallet, BigNumber, utils } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { hexValue, hexZeroPad } from 'ethers/lib/utils';

import { hexDataLength } from '@ethersproject/bytes'
import {
  L1ToL2MessageGasEstimator,
} from '@arbitrum/sdk/dist/lib/message/L1ToL2MessageGasEstimator'
import {
  L1TransactionReceipt,
  L1ToL2MessageStatus
} from '@arbitrum/sdk'

// get providers for source and destination
const walletPrivateKey = process.env.DEVNET_PRIVKEY
const l1Provider = new providers.JsonRpcProvider(process.env.L1RPC)
const l2Provider = new providers.JsonRpcProvider(process.env.L2RPC)

const l1Wallet = new Wallet(walletPrivateKey, l1Provider)
const l2Wallet = new Wallet(walletPrivateKey, l2Provider)

const amount = 100
const msgGasLimit = 150000
const proof = "0x0000000000000000000000000000000000000000000000000000000000000000"
const localChainId = 5;
const remoteChainId = 421613;

export const main = async () => {
  try {
    if (!remoteChainId)
      throw new Error("Provide remote chain id");

    if (!fs.existsSync(deployedAddressPath + localChainId + ".json") || !fs.existsSync(deployedAddressPath + remoteChainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const l1Config: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + localChainId + ".json", "utf-8"));
    console.log(l1Config)
    const l2Config: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + remoteChainId + ".json", "utf-8"))
    console.log(l2Config)

    // get socket contracts for both chains
    // counter l1, counter l2, seal, execute
    const l1Counter: Contract = (await getInstance("Counter", l1Config["counter"])).connect(l1Wallet);
    const l2Counter: Contract = (await getInstance("Counter", l2Config["counter"])).connect(l2Wallet);

    const l1Notary: Contract = (await getInstance("AdminNotary", l1Config["notary"])).connect(l1Wallet);
    const l2Socket: Contract = (await getInstance("Socket", l2Config["socket"])).connect(l2Wallet);

    const arbitrumAccumL1: Contract = (await getInstance("ArbitrumL1Accum", l1Config["arbitrumAccum-421613"])).connect(l1Wallet);

    // outbound
    const outboundTx = await l1Counter.remoteAddOperation(remoteChainId, amount, msgGasLimit);
    await outboundTx.wait()

    // seal
    const payload = keccak256(defaultAbiCoder.encode(["bytes32", "uint256"], [utils.solidityKeccak256(["string"], ["OP_ADD"]), amount]));
    const packetId = packPacketId(localChainId, arbitrumAccumL1.address, "0")
    const msgId = packMsgId(localChainId, "0");

    console.log([
      localChainId,
      l1Config["counter"],
      remoteChainId,
      l2Config["counter"],
      msgId,
      msgGasLimit,
      payload
    ])

    const root = keccak256(defaultAbiCoder.encode(
      [
        "uint256",
        "address",
        "uint256",
        "address",
        "uint256",
        "uint256",
        "bytes"
      ],
      [
        localChainId,
        l1Config["counter"],
        remoteChainId,
        l2Config["counter"],
        msgId,
        msgGasLimit,
        payload
      ]
    ));

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["uint256", "uint256", "bytes32"],
        [remoteChainId, packetId, root]
      )
    );
    const signature = await l1Wallet.signMessage(arrayify(digest));

    const { bridgeParams, callValue } = await getBridgeParams(packetId, root, signature, arbitrumAccumL1.address, l2Config["notary"]);
    const sealTx = await l1Notary.seal(arbitrumAccumL1.address, bridgeParams, signature, {
      value: callValue,
    });
    const sealTxReceipt = await sealTx.wait()

    // wait for msg to arrive on l2
    console.log(
      `Seal txn confirmed on L1! 🙌 ${sealTxReceipt.transactionHash}`
    )

    const l1TxReceipt = new L1TransactionReceipt(sealTxReceipt)

    /**
   * In principle, a single L1 txn can trigger any number of L1-to-L2 messages (each with its own sequencer number).
   * In this case, we know our txn triggered only one
   * Here, We check if our L1 to L2 message is redeemed on L2
   */
    const messages = await l1TxReceipt.getL1ToL2Messages(l2Wallet)
    const message = messages[0]
    console.log('Waiting for L2 side. It may take 10-15 minutes ⏰⏰')
    const messageResult = await message.waitForStatus()
    const status = messageResult.status
    if (status === L1ToL2MessageStatus.REDEEMED) {
      console.log(
        `L2 retryable txn executed 🥳 ${messageResult.l2TxReceipt.transactionHash}`
      )
    } else {
      console.log(
        `L2 retryable txn failed with status ${L1ToL2MessageStatus[status]}`
      )
    }

    // execute msg
    const executeTx = await l2Socket.execute(
      msgGasLimit,
      msgId,
      l2Config["counter"],
      payload,
      [
        localChainId,
        packetId,
        proof
      ]
    )
    await executeTx.wait()

    const counter = await l2Counter.counter();
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

export const getBridgeParams = async (packetNonce, root, signature, from, to) => {
  const attestBytes = defaultAbiCoder.encode(
    ['uint256', 'bytes32', 'bytes'],
    [packetNonce, root, signature]
  )
  const attestBytesLength = hexDataLength(attestBytes) + 4 // 4 bytes func identifier

  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider)

  const _submissionPriceWei =
    await l1ToL2MessageGasEstimate.estimateSubmissionFee(
      l1Provider,
      await l1Provider.getGasPrice(),
      attestBytesLength
    )

  console.log(
    `Current retryable base submission price: ${_submissionPriceWei.toString()}`
  )

  /**
   * ...Okay, but on the off chance we end up underpaying, our retryable ticket simply fails.
   * This is highly unlikely, but just to be safe, let's increase the amount we'll be paying (the difference between the actual cost and the amount we pay gets refunded to our address on L2 anyway)
   * In nitro, submission fee will be charged in L1 based on L1 basefee, revert on L1 side upon insufficient fee.
   */
  const submissionPriceWei = _submissionPriceWei.mul(5)
  /**
   * Now we'll figure out the gas we need to send for L2 execution; this requires the L2 gas price and gas limit for our L2 transaction
   */

  /**
   * For the L2 gas price, we simply query it from the L2 provider, as we would when using L1
   */
  const gasPriceBid = await l2Provider.getGasPrice()
  console.log(`L2 gas price: ${gasPriceBid.toString()}`)

  /**
   * For the gas limit, we'll use the estimateRetryableTicketGasLimit method in Arbitrum SDK
   */

  /**
   * First, we need to calculate the calldata for the function being called (setGreeting())
   */
  const ABI = ['function attest(uint256 packetId_,bytes32 root_,bytes calldata signature_)']
  const iface = new utils.Interface(ABI)
  const calldata = iface.encodeFunctionData('attest', [packetNonce, root, signature])
  const maxGas = await l1ToL2MessageGasEstimate.estimateRetryableTicketGasLimit(
    {
      from,
      to,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: await l1Wallet.address,
      callValueRefundAddress: await l2Wallet.address,
      data: calldata,
    },
    utils.parseEther('1')
  )
  /**
   * With these three values, we can calculate the total callvalue we'll need our L1 transaction to send to L2
   */
  const callValue = submissionPriceWei.add(gasPriceBid.mul(maxGas))

  console.log(
    `Sending greeting to L2 with ${callValue.toString()} callValue for L2 fees:`
  )

  return { bridgeParams: [submissionPriceWei, maxGas, gasPriceBid], callValue }
}

export const packPacketId = (
  chainSlug: number,
  accumAddr: string,
  packetNonce: string
): string => {
  const nonce = BigNumber.from(packetNonce).toHexString();
  const nonceHex = nonce.length <= 16 ? hexZeroPad(nonce, 8).substring(2,) : nonce.substring(2,);
  const id = BigNumber.from(chainSlug).toHexString() + hexValue(accumAddr).substring(2,) + nonceHex;

  return BigNumber.from(id).toString();
};

export const packMsgId = (
  chainSlug: number,
  msgNonce: string
): string => {
  const nonce = BigNumber.from(msgNonce).toHexString();
  const nonceHex = nonce.length <= 16 ? hexZeroPad(nonce, 8).substring(2,) : nonce.substring(2,);
  const id = BigNumber.from(chainSlug).toHexString() + nonceHex;

  return BigNumber.from(id).toString();
};
