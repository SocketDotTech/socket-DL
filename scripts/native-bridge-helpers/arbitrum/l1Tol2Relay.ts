import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { Contract, providers, Wallet, BigNumber, utils } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { hexDataLength } from "@ethersproject/bytes";
import { L1ToL2MessageGasEstimator } from "@arbitrum/sdk/dist/lib/message/L1ToL2MessageGasEstimator";
import { L1TransactionReceipt, L1ToL2MessageStatus } from "@arbitrum/sdk";

import { getInstance, deployedAddressPath } from "../../deploy/utils";
import { packPacketId } from "../../deploy/scripts/packetId";
import { chainSlugs, getJsonRpcUrl, DeploymentMode } from "../../constants";

// get providers for source and destination
const localChain = "goerli";
const remoteChain = "arbitrum-goerli";
const outboundTx =
  "0x6a2da0a61caf7f724125e5a2b90431a3c0d8f6977450c1ea98f983847f657690";
const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;

const walletPrivateKey = process.env.DEVNET_PRIVKEY;
const l1Provider = new providers.JsonRpcProvider(getJsonRpcUrl(localChain));
const l2Provider = new providers.JsonRpcProvider(getJsonRpcUrl(remoteChain));

const l1Wallet = new Wallet(walletPrivateKey, l1Provider);
const l2Wallet = new Wallet(walletPrivateKey, l2Provider);

export const getBridgeParams = async (
  packetNonce,
  root,
  signature,
  from,
  to
) => {
  const attestBytes = defaultAbiCoder.encode(
    ["uint256", "bytes32", "bytes"],
    [packetNonce, root, signature]
  );
  const attestBytesLength = hexDataLength(attestBytes) + 4; // 4 bytes func identifier

  const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(l2Provider);

  const _submissionPriceWei =
    await l1ToL2MessageGasEstimate.estimateSubmissionFee(
      l1Provider,
      await l1Provider.getGasPrice(),
      attestBytesLength
    );

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

  const ABI = [
    "function attest(uint256 packetId_,bytes32 root_,bytes calldata signature_)",
  ];
  const iface = new utils.Interface(ABI);
  const calldata = iface.encodeFunctionData("attest", [
    packetNonce,
    root,
    signature,
  ]);

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
  /**
   * With these three values, we can calculate the total callvalue we'll need our L1 transaction to send to L2
   */
  const callValue = submissionPriceWei.add(gasPriceBid.mul(maxGas));

  console.log(
    `Sending greeting to L2 with ${callValue.toString()} callValue for L2 fees:`
  );

  return { bridgeParams: [submissionPriceWei, maxGas, gasPriceBid], callValue };
};

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

    const l1Config = addresses[chainSlugs[localChain]];
    const l2Config = addresses[chainSlugs[remoteChain]];

    // get socket contracts for both chains
    // counter l1, counter l2, seal, execute
    const contracts = contractNames("", localChain, remoteChain);

    const l1Capacitor: Contract = (
      await getInstance(
        "SingleCapacitor",
        l1Config["integrations"]?.[chainSlugs[remoteChain]]?.[
          contracts.integrationType
        ]?.["capacitor"]
      )
    ).connect(l1Wallet);
    const l1Notary: Contract = (
      await getInstance(
        contracts.notary,
        l1Config["integrations"]?.[chainSlugs[remoteChain]]?.[
          contracts.integrationType
        ]?.["notary"]
      )
    ).connect(l1Wallet);

    const outboundTxReceipt = await l1Provider.getTransactionReceipt(
      outboundTx
    );

    // seal
    const { packetId, newRootHash } = l1Capacitor.interface.decodeEventLog(
      "MessageAdded",
      outboundTxReceipt.logs[1].data
    );
    const packedPacketId = packPacketId(
      chainSlugs[localChain],
      l1Capacitor.address,
      packetId
    );

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["uint256", "uint256", "bytes32"],
        [chainSlugs[remoteChain], packedPacketId, newRootHash]
      )
    );

    const signature = await l1Wallet.signMessage(arrayify(digest));
    const { bridgeParams, callValue } = await getBridgeParams(
      packedPacketId,
      newRootHash,
      "0x",
      l1Notary.address,
      l2Config["integrations"]?.[chainSlugs[localChain]]?.[
        contracts.integrationType
      ]?.["notary"]
    );

    console.log(
      `Sealing with params ${
        (l1Capacitor.address, bridgeParams, signature, callValue)
      }`
    );

    const sealTx = await l1Notary.seal(
      l1Capacitor.address,
      bridgeParams,
      signature,
      {
        value: callValue,
      }
    );

    const sealTxReceipt = await sealTx.wait();

    // wait for msg to arrive on l2
    console.log(
      `Seal txn confirmed on L1! 🙌 ${sealTxReceipt.transactionHash}`
    );

    const l1TxReceipt = new L1TransactionReceipt(sealTxReceipt);

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
