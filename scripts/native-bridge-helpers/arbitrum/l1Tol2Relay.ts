import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { Contract, providers, Wallet, BigNumber, utils } from "ethers";
import { hexDataLength } from "@ethersproject/bytes";
import { L1ToL2MessageGasEstimator } from "@arbitrum/sdk/dist/lib/message/L1ToL2MessageGasEstimator";

import { getInstance } from "../../deploy/utils";
import { getJsonRpcUrl } from "../../constants";
import { mode, socketOwner } from "../../deploy/config";
import {
  ChainKey,
  IntegrationTypes,
  chainKeyToSlug,
  getAllAddresses,
  getSwitchboardAddress,
} from "../../../src";
import { L1ToL2MessageStatus, L1TransactionReceipt } from "@arbitrum/sdk";

// get providers for source and destination
const l1Chain = ChainKey.GOERLI;
const l2Chain = ChainKey.ARBITRUM_GOERLI;
const packetId =
  "0x00000005feb89935220606f3c3670ae510a74ab5750e810c0000000000000000";
const root =
  "0xc8111d45052c1df62037b92c1fab7c23bda80a0854b81432aee514aaf5f6c440";

const walletPrivateKey = process.env.SOCKET_SIGNER_KEY;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l1Chain));
const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(l2Chain));

const l1Wallet = new Wallet(walletPrivateKey, l1Provider);
const l2Wallet = new Wallet(walletPrivateKey, l2Provider);

export const getBridgeParams = async (from, to) => {
  const receivePacketBytes = utils.defaultAbiCoder.encode(
    ["bytes32", "bytes32"],
    [packetId, root]
  );

  console.log(receivePacketBytes, "receivePacketBytes");

  const receivePacketBytesLength = hexDataLength(receivePacketBytes) + 4; // 4 bytes func identifier
  console.log(`${receivePacketBytesLength}`, "receivePacketBytesLength");

  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider);
  const submissionPriceWei = (
    await l1ToL2MessageGasEstimate.estimateSubmissionFee(
      l1Provider,
      await l1Provider.getGasPrice(),
      receivePacketBytesLength
    )
  ).mul(5);

  console.log(
    `Current retryable base submission price: ${submissionPriceWei.toString()}`
  );
  const gasPriceBid = await l2Provider.getGasPrice();
  console.log(`L2 gas price: ${gasPriceBid.toString()}`);

  const ABI = ["function receivePacket(bytes32 packetId_,bytes32 root_)"];
  const iface = new utils.Interface(ABI);
  const calldata = iface.encodeFunctionData("receivePacket", [packetId, root]);
  console.log(calldata, "calldata");

  const maxGas = await l1ToL2MessageGasEstimate.estimateRetryableTicketGasLimit(
    {
      from,
      to,
      l2CallValue: BigNumber.from(0),
      excessFeeRefundAddress: socketOwner,
      callValueRefundAddress: socketOwner,
      data: calldata,
    },
    utils.parseEther("1")
  );

  console.log(from, to, "from,to, from,to, from,to, from,to, from,to, ");
  const callValue = submissionPriceWei.add(gasPriceBid.mul(maxGas));
  console.log(
    `Sending greeting to L2 with ${callValue.toString()} callValue for L2 fees:`
  );
  return {
    bridgeParams: [submissionPriceWei, maxGas, gasPriceBid],
    callValue,
  };
};

export const main = async () => {
  try {
    const addresses = getAllAddresses(mode);

    if (
      !addresses[chainKeyToSlug[l1Chain]] ||
      !addresses[chainKeyToSlug[l2Chain]]
    ) {
      throw new Error("Deployed Addresses not found");
    }

    const l1Config = addresses[chainKeyToSlug[l1Chain]];
    const l2Config = addresses[chainKeyToSlug[l2Chain]];

    // get socket contracts for both chains
    // counter l1, counter l2, initiateNative, execute

    const sbAddr = getSwitchboardAddress(
      chainKeyToSlug[l1Chain],
      chainKeyToSlug[l2Chain],
      IntegrationTypes.native,
      mode
    );
    const l1Switchboard: Contract = (
      await getInstance("ArbitrumL1Switchboard", sbAddr)
    ).connect(l1Wallet);

    // initiateNative
    const { bridgeParams, callValue } = await getBridgeParams(
      l1Switchboard.address,
      getSwitchboardAddress(
        chainKeyToSlug[l2Chain],
        chainKeyToSlug[l1Chain],
        IntegrationTypes.native,
        mode
      )
    );

    console.log(
      `Sealing with params ${
        (l1Switchboard.address, packetId, bridgeParams, callValue)
      }`
    );

    const initiateNativeTx = await l1Switchboard.initiateNativeConfirmation(
      packetId,
      bridgeParams[0],
      bridgeParams[1],
      bridgeParams[2],
      {
        value: callValue,
      }
    );

    const initiateNativeTxReceipt = await initiateNativeTx.wait();

    // wait for msg to arrive on l2
    console.log(
      `Seal txn confirmed on L1! 🙌 ${initiateNativeTxReceipt.transactionHash}`
    );

    const l1TxReceipt = new L1TransactionReceipt(initiateNativeTxReceipt);

    /**
     * In principle, a single L1 txn can trigger any number of L1-to-L2 messages (each with its own sequencer number).
     * In this case, we know our txn triggered only one
     * Here, We check if our L1 to L2 message is redeemed on L2
     */
    const messages = await l1TxReceipt.getL1ToL2Messages(l2Wallet);
    const message = messages[0];
    console.log("Waiting for L2 side. It may take 10-15 minutes ⏰⏰");
    const messageResult = await message.waitForStatus();
    const status = messageResult.status;
    if (status === L1ToL2MessageStatus.REDEEMED) {
      console.log(
        `L2 retryable txn executed 🥳 ${messageResult.l2TxReceipt.transactionHash}`
      );
    } else {
      console.log(
        `L2 retryable txn failed with status ${L1ToL2MessageStatus[status]}`
      );
    }
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
