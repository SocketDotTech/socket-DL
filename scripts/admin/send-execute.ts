import { config as dotenvConfig } from "dotenv";
import {
  ChainSlug,
  DeploymentAddresses,
  getAllAddresses,
  getOverrides,
} from "../../src";
import { mode, overrides } from "../deploy/config/config";
import SocketArtifact from "../../out/Socket.sol/Socket.json";
import { getProviderFromChainSlug } from "../constants";
import { ethers, Wallet } from "ethers";
import { getAwsKmsSigner } from "@socket.tech/dl-common";

dotenvConfig();

/**
 * Usage
 *
 * --sourcetxhash   Specify the source transaction hash containing the MessageOutbound event.
 *                  This flag is required.
 *                  Eg. npx --sourcetxhash=0x123... --kmskeyid=abc-123 ts-node scripts/admin/send-execute.ts
 *
 * --kmskeyid       Specify the AWS KMS key ID for executor signature.
 *                  This flag is required.
 *
 * --packetid       Specify the packet ID for execution (optional, defaults to 0x00...00).
 *                  Eg. npx --sourcetxhash=0x123... --kmskeyid=abc-123 --packetid=0xabc... ts-node scripts/admin/send-execute.ts
 *
 * --proposalcount  Specify the proposal count (optional, defaults to 0).
 *                  Eg. npx --sourcetxhash=0x123... --kmskeyid=abc-123 --proposalcount=1 ts-node scripts/admin/send-execute.ts
 *
 * --gaslimit       Specify the execution gas limit (optional, defaults to 500000).
 *                  Eg. npx --sourcetxhash=0x123... --kmskeyid=abc-123 --gaslimit=200000 ts-node scripts/admin/send-execute.ts
 *
 * --sendtx         Send execute tx along with signature generation.
 *                  Default is only generate and display signature.
 *                  Eg. npx --sourcetxhash=0x123... --kmskeyid=abc-123  --sendtx ts-node scripts/admin/send-execute.ts
 */

const sourceTxHash = process.env.npm_config_sourcetxhash;
if (!sourceTxHash) {
  console.error("Error: sourcetxhash flag is required");
  process.exit(1);
}

const packetId =
  process.env.npm_config_packetid ||
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const proposalCount = process.env.npm_config_proposalcount || "0";
const executionGasLimit = process.env.npm_config_gaslimit || "500000";

const kmsKeyId = process.env.npm_config_kmskeyid;
if (!kmsKeyId) {
  console.error("Error: kmskeyid flag is required");
  process.exit(1);
}

const sendTx = process.env.npm_config_sendtx === "true";

const signerKey = process.env.SOCKET_SIGNER_KEY;
if (sendTx && !signerKey) {
  console.error("Error: SOCKET_SIGNER_KEY is required when sending tx");
  process.exit(1);
}

const addresses: DeploymentAddresses = getAllAddresses(mode);

// MessageOutbound event ABI
const MESSAGE_OUTBOUND_ABI = [
  "event MessageOutbound(uint32 indexed localChainSlug, address localPlug, address dstPlug, uint32 indexed dstChainSlug, bytes32 indexed msgId, uint256 minMsgGasLimit, bytes32 executionParams, bytes32 transmissionParams, bytes payload, tuple(uint256 feePoolChain, uint256 feePoolToken, uint256 maxFees) fees)",
];

export const main = async () => {
  console.log(
    `\nFetching MessageOutbound event from source transaction: ${sourceTxHash}\n`
  );

  // First, we need to get the transaction receipt to determine the source chain
  // We'll try to fetch the receipt from all chains until we find it
  let sourceChain: ChainSlug | undefined;
  let sourceProvider: ethers.providers.Provider | undefined;
  let txReceipt: ethers.providers.TransactionReceipt | undefined;

  console.log("Searching for transaction across chains...");
  for (const [chainSlug, chainAddresses] of Object.entries(addresses)) {
    try {
      const chain = parseInt(chainSlug) as ChainSlug;
      const provider = getProviderFromChainSlug(chain);
      const receipt = await provider.getTransactionReceipt(sourceTxHash);

      if (receipt && receipt.blockNumber) {
        sourceChain = chain;
        sourceProvider = provider;
        txReceipt = receipt;
        console.log(`Found transaction on chain: ${sourceChain}`);
        break;
      }
    } catch (error) {
      // Continue searching
    }
  }

  if (!sourceChain || !sourceProvider || !txReceipt) {
    console.error("Error: Could not find transaction on any configured chain");
    process.exit(1);
  }

  // Parse logs to find MessageOutbound event
  const socketInterface = new ethers.utils.Interface([
    ...SocketArtifact.abi,
    ...MESSAGE_OUTBOUND_ABI,
  ]);
  const messageOutboundTopic = socketInterface.getEventTopic("MessageOutbound");

  const messageOutboundLog = txReceipt.logs.find(
    (log) => log.topics[0] === messageOutboundTopic
  );

  if (!messageOutboundLog) {
    console.error("Error: MessageOutbound event not found in transaction");
    process.exit(1);
  }

  const parsedEvent = socketInterface.parseLog(messageOutboundLog);
  console.log("\nParsed MessageOutbound Event:");
  console.log(`  Local Chain Slug: ${parsedEvent.args.localChainSlug}`);
  console.log(`  Local Plug: ${parsedEvent.args.localPlug}`);
  console.log(`  Destination Plug: ${parsedEvent.args.dstPlug}`);
  console.log(`  Destination Chain Slug: ${parsedEvent.args.dstChainSlug}`);
  console.log(`  Message ID: ${parsedEvent.args.msgId}`);
  console.log(
    `  Min Message Gas Limit: ${parsedEvent.args.minMsgGasLimit.toString()}`
  );
  console.log(`  Execution Params: ${parsedEvent.args.executionParams}`);
  console.log(`  Payload: ${parsedEvent.args.payload}\n`);

  const destinationChain = parsedEvent.args.dstChainSlug as ChainSlug;

  // Get addresses from prod_addresses.json
  const destinationAddresses = addresses[destinationChain];
  if (!destinationAddresses) {
    console.error(
      `Error: No addresses found for destination chain ${destinationChain}`
    );
    process.exit(1);
  }

  const socketAddress = destinationAddresses.Socket;

  console.log("Destination Addresses:");
  console.log(`  Socket: ${socketAddress}\n`);

  // Get provider
  const provider = getProviderFromChainSlug(destinationChain);

  // Get Socket contract to access hasher
  const socketContract = new ethers.Contract(
    socketAddress,
    SocketArtifact.abi,
    provider
  );

  // Get hasher address
  const hasherAddress = await socketContract.hasher__();
  console.log(`Hasher address: ${hasherAddress}`);

  // Get hasher contract
  const hasherAbi = [
    "function packMessage(uint32 srcChainSlug_, address srcPlug_, uint32 dstChainSlug_, address dstPlug_, tuple(bytes32 msgId, uint256 executionFee, uint256 minMsgGasLimit, bytes32 executionParams, bytes payload) messageDetails_) external pure returns (bytes32)",
  ];
  const hasherContract = new ethers.Contract(
    hasherAddress,
    hasherAbi,
    provider
  );

  // Use data from parsed event
  const srcChainSlug = sourceChain;
  const srcPlug = parsedEvent.args.localPlug;
  const dstPlug = parsedEvent.args.dstPlug;

  // Get plug config to find siblingPlug (for verification)
  const plugConfig = await socketContract.getPlugConfig(dstPlug, srcChainSlug);
  const siblingPlug = plugConfig.siblingPlug;

  console.log(`Verification - Sibling Plug: ${siblingPlug}\n`);

  // Prepare message details
  const messageDetails = {
    msgId: parsedEvent.args.msgId,
    executionFee: "0", // Execution fee is 0 for manual execution
    minMsgGasLimit: parsedEvent.args.minMsgGasLimit.toString(),
    executionParams: parsedEvent.args.executionParams,
    payload: parsedEvent.args.payload,
  };

  // Pack message for signature
  const packedMessage = await hasherContract.packMessage(
    srcChainSlug,
    srcPlug,
    destinationChain,
    dstPlug,
    [
      messageDetails.msgId,
      messageDetails.executionFee,
      messageDetails.minMsgGasLimit,
      messageDetails.executionParams,
      messageDetails.payload,
    ]
  );

  console.log("Packed message:", packedMessage);

  // Get AWS KMS signer
  console.log("\nGetting AWS KMS signer...");
  const kmsSigner = (await getAwsKmsSigner(kmsKeyId)).connect(provider);
  const kmsAddress = await kmsSigner.getAddress();
  console.log(`KMS Address (Executor): ${kmsAddress}`);

  // Sign with KMS
  console.log("\nSigning packed message with AWS KMS...");
  const signature = await kmsSigner.signMessage(
    ethers.utils.arrayify(packedMessage)
  );
  console.log("Signature:", signature);

  // Prepare transaction structs
  const executionDetails = {
    packetId: packetId,
    proposalCount: proposalCount,
    executionGasLimit: executionGasLimit,
    decapacitorProof: "0x",
    signature: signature,
  };

  console.log("\n=== Execution Details ===");
  console.log(`Packet ID: ${executionDetails.packetId}`);
  console.log(`Proposal Count: ${executionDetails.proposalCount}`);
  console.log(`Execution Gas Limit: ${executionDetails.executionGasLimit}`);
  console.log(`Decapacitor Proof: ${executionDetails.decapacitorProof}`);
  console.log("===========================\n");

  // Prepare transaction data
  const txSocketInterface = new ethers.utils.Interface(SocketArtifact.abi);
  const calldata = txSocketInterface.encodeFunctionData("execute", [
    executionDetails,
    messageDetails,
  ]);

  console.log("\n=== Transaction Details ===");
  console.log(`Chain ID: ${(await provider.getNetwork()).chainId}`);
  console.log(`Target: ${socketAddress}`);
  console.log(`Value: 0`);
  console.log(`Calldata: ${calldata}`);
  console.log("===========================\n");

  if (sendTx) {
    console.log("Sending execute transaction...");

    const wallet = new Wallet(signerKey!, provider);
    const socketContractWithSigner = new ethers.Contract(
      socketAddress,
      SocketArtifact.abi,
      wallet
    );

    const tx = await socketContractWithSigner.execute(
      executionDetails,
      messageDetails,
      {
        value: 0,
        ...(await getOverrides(destinationChain, provider)),
      }
    );

    console.log("Transaction hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed in block:", receipt.blockNumber);
    console.log("Gas used:", receipt.gasUsed.toString());
  } else {
    console.log("To send the execute transaction, add --sendtx flag");
    console.log(
      "You can use the transaction details above to manually send, simulate, or audit the transaction."
    );
  }

  console.log("\nScript completed.");
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
