import fs from "fs";
import { Contract, providers, Wallet, BigNumber, utils } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { hexDataLength } from "@ethersproject/bytes";
import { L1ToL2MessageGasEstimator } from "@arbitrum/sdk/dist/lib/message/L1ToL2MessageGasEstimator";
import { L1TransactionReceipt, L1ToL2MessageStatus } from "@arbitrum/sdk";

import { getInstance, deployedAddressPath } from "../../deploy/utils";
import { packPacketId } from "../../deploy/scripts/packetId";
import { chainSlugs, getJsonRpcUrl } from "../../constants";
import { IntegrationTypes } from "../../../src";

// get providers for source and destination
const localChain = "mainnet";
const remoteChain = "arbitrum";

const walletPrivateKey = process.env.DEVNET_PRIVKEY;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(localChain));
const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(remoteChain));

const l1Wallet = new Wallet(walletPrivateKey, l1Provider);
const l2Wallet = new Wallet(walletPrivateKey, l2Provider);

export const getBridgeParams = async (packetId, root, from, to) => {
  const receivePacketBytes = utils.defaultAbiCoder.encode(
    ["bytes32", "bytes32"],
    [packetId, root]
  );
  const receivePacketBytesLength = hexDataLength(receivePacketBytes) + 4; // 4 bytes func identifier
  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider);
  const _submissionPriceWei = (
    await l1ToL2MessageGasEstimate.estimateSubmissionFee(
      l1Provider,
      await l1Provider.getGasPrice(),
      receivePacketBytesLength
    )
  ).mul(5);

  console.log(
    `Current retryable base submission price: ${_submissionPriceWei.toString()}`
  );

  /**
   * ...Okay, but on the off chance we end up underpaying, our retryable ticket simply fails.
   * This is highly unlikely, but just to be safe, let's increase the amount we'll be paying (the difference between the actual cost and the amount we pay gets refunded to our address on L2 anyway)
   * In nitro, submission fee will be charged in L1 based on L1 basefee, revert on L1 side upon insufficient fee.
   */
  const submissionPriceWei = _submissionPriceWei.mul(5);
  /**
   * Now we'll figure out the gas we need to send for L2 execution; this requires the L2 gas price and gas limit for our L2 transaction
   */

  /**
   * For the L2 gas price, we simply query it from the L2 provider, as we would when using L1
   */
  const gasPriceBid = await l2Provider.getGasPrice();
  console.log(`L2 gas price: ${gasPriceBid.toString()}`);

  /**
   * For the gas limit, we'll use the estimateRetryableTicketGasLimit method in Arbitrum SDK
   */

  /**
   * First, we need to calculate the calldata for the function being called (setGreeting())
   */

  const ABI = ["function receivePacket(bytes32 packetId_,bytes32 root_)"];
  const iface = new utils.Interface(ABI);
  const calldata = iface.encodeFunctionData("receivePacket", [packetId, root]);

  const maxGas = await l1ToL2MessageGasEstimate.estimateRetryableTicketGasLimit(
    {
      from,
      to,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: await l1Wallet.address,
      callValueRefundAddress: await l2Wallet.address,
      data: calldata,
    },
    utils.parseEther("1")
  );
  const callValue = submissionPriceWei.add(gasPriceBid.mul(maxGas));
  console.log(
    `Sending greeting to L2 with ${callValue.toString()} callValue for L2 fees:`
  );

  return { bridgeParams: [submissionPriceWei, maxGas, gasPriceBid], callValue };
};

export const main = async () => {
  try {
    if (!fs.existsSync(deployedAddressPath)) {
      throw new Error("addresses.json not found");
    }
    const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));

    if (
      !addresses[chainSlugs[localChain]] ||
      !addresses[chainSlugs[remoteChain]]
    ) {
      throw new Error("Deployed Addresses not found");
    }

    const l1Config = addresses[chainSlugs[localChain]];
    const l2Config = addresses[chainSlugs[remoteChain]];

    const packetId =
      "0x000000014beb2359fe958763a59375ebfd13413a586e5add0000000000000000";
    const root =
      "0xfdf8d28b543201f1dc7d9759728bf1f36aa1b2eae5a256dd00c0128b6760985f";

    const { bridgeParams, callValue } = await getBridgeParams(
      packetId,
      root,
      l1Config["integrations"]?.[chainSlugs[remoteChain]]?.[
        IntegrationTypes.native
      ]?.["switchboard"],
      l2Config["integrations"]?.[chainSlugs[localChain]]?.[
        IntegrationTypes.native
      ]?.["switchboard"]
    );

    console.log(`Initiating with params ${bridgeParams} and ${callValue}`);

    // const sealTx = await l1Notary.seal(
    //   l1Capacitor.address,
    //   bridgeParams,
    //   signature,
    //   {
    //     value: callValue,
    //   }
    // );

    // const sealTxReceipt = await sealTx.wait();

    // // wait for msg to arrive on l2
    // console.log(
    //   `Seal txn confirmed on L1! 🙌 ${sealTxReceipt.transactionHash}`
    // );

    // const l1TxReceipt = new L1TransactionReceipt(sealTxReceipt);

    // /**
    //  * In principle, a single L1 txn can trigger any number of L1-to-L2 messages (each with its own sequencer number).
    //  * In this case, we know our txn triggered only one
    //  * Here, We check if our L1 to L2 message is redeemed on L2
    //  */
    // const messages = await l1TxReceipt.getL1ToL2Messages(l2Wallet);
    // const message = messages[0];
    // console.log("Waiting for L2 side. It may take 10-15 minutes ⏰⏰");
    // const messageResult = await message.waitForStatus();
    // const status = messageResult.status;
    // if (status === L1ToL2MessageStatus.REDEEMED) {
    //   console.log(
    //     `L2 retryable txn executed 🥳 ${messageResult.l2TxReceipt.transactionHash}`
    //   );
    // } else {
    //   console.log(
    //     `L2 retryable txn failed with status ${L1ToL2MessageStatus[status]}`
    //   );
    // }
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
