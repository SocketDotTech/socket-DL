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
 * --destination    Specify the destination chain slug where execute will be called.
 *                  This flag is required.
 *                  Eg. npx --destination=10 --kmskeyid=abc-123 ts-node scripts/admin/send-execute.ts
 *
 * --kmskeyid       Specify the AWS KMS key ID for executor signature.
 *                  This flag is required.
 *
 * --sendtx         Send execute tx along with signature generation.
 *                  Default is only generate and display signature.
 *                  Eg. npx --destination=10 --kmskeyid=abc-123  --sendtx ts-node scripts/admin/send-execute.ts
 */

// Configuration object with execution and message details
const EXECUTION_CONFIG = {
  executionDetails: {
    packetId: "0x0000a4b129ebc834d24af22b9466a4150425354998c3e800000000000000cbe6", // Replace with actual packet ID
    proposalCount: "0", // Replace with actual proposal count
    executionGasLimit: "200000", // Replace with actual gas limit
    decapacitorProof: "0x", // Replace with actual proof
  },
  messageDetails: {
    msgId: "0x0000a4b126e5ce884875ea3776a57f0b225b1ea8d2e9beeb00000000000608cb", // Replace with actual message ID
    executionFee: "0", // Replace with actual execution fee
    minMsgGasLimit: "100000", // Replace with actual min gas limit
    executionParams: "0x0000000000000000000000000000000000000000000000000000000000000000", // Replace with actual execution params
    payload: "0x0000000000000000000000008cb4c89cc297e07c7a309af8b16cc2f5f62a3b1300000000000000000000000000000000000000000000000000000000062ebe4d", // Replace with actual payload
  },
  msgValue: "0", // ETH value to send with transaction (in wei)
};

const destinationChainSlug = process.env.npm_config_destination;
if (!destinationChainSlug) {
  console.error("Error: destination flag is required");
  process.exit(1);
}

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

export const main = async () => {
  const destinationChain = parseInt(destinationChainSlug) as ChainSlug;

  console.log(`\nProcessing execute transaction for chain: ${destinationChain}\n`);

  // Get addresses from prod_addresses.json
  const destinationAddresses = addresses[destinationChain];
  if (!destinationAddresses) {
    console.error(
      `Error: No addresses found for destination chain ${destinationChain}`
    );
    process.exit(1);
  }

  const socketAddress = destinationAddresses.Socket;

  console.log("Addresses:");
  console.log(`  Socket: ${socketAddress}\n`);

  console.log("Execution Configuration:");
  console.log("  ExecutionDetails:");
  console.log(`    Packet ID: ${EXECUTION_CONFIG.executionDetails.packetId}`);
  console.log(`    Proposal Count: ${EXECUTION_CONFIG.executionDetails.proposalCount}`);
  console.log(`    Execution Gas Limit: ${EXECUTION_CONFIG.executionDetails.executionGasLimit}`);
  console.log(`    Decapacitor Proof: ${EXECUTION_CONFIG.executionDetails.decapacitorProof}`);
  console.log("  MessageDetails:");
  console.log(`    Message ID: ${EXECUTION_CONFIG.messageDetails.msgId}`);
  console.log(`    Execution Fee: ${EXECUTION_CONFIG.messageDetails.executionFee}`);
  console.log(`    Min Message Gas Limit: ${EXECUTION_CONFIG.messageDetails.minMsgGasLimit}`);
  console.log(`    Execution Params: ${EXECUTION_CONFIG.messageDetails.executionParams}`);
  console.log(`    Payload: ${EXECUTION_CONFIG.messageDetails.payload}`);
  console.log(`  Message Value: ${EXECUTION_CONFIG.msgValue}\n`);

  // Get provider
  const provider = getProviderFromChainSlug(
    destinationChain
  );

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
    "function packMessage(uint32 srcChainSlug_, address srcPlug_, uint32 dstChainSlug_, address dstPlug_, tuple(bytes32 msgId, uint256 executionFee, uint256 minMsgGasLimit, bytes32 executionParams, bytes payload) messageDetails_) external pure returns (bytes32)"
  ];
  const hasherContract = new ethers.Contract(hasherAddress, hasherAbi, provider);

  // Extract chain slug and plug from msgId
  // msgId format: chainSlug (32 bits) | plug (160 bits) | messageCount (64 bits)
  const msgIdBigInt = BigInt(EXECUTION_CONFIG.messageDetails.msgId);
  const srcChainSlug = Number((msgIdBigInt >> BigInt(224)) & BigInt(0xFFFFFFFF));
  const dstPlug = "0x" + ((msgIdBigInt >> BigInt(64)) & ((BigInt(1) << BigInt(160)) - BigInt(1))).toString(16).padStart(40, "0");

  console.log(`\nExtracted from msgId:`);
  console.log(`  Source Chain Slug: ${srcChainSlug}`);
  console.log(`  Destination Plug: ${dstPlug}`);

  // Get plug config to find siblingPlug
  const plugConfig = await socketContract.getPlugConfig(dstPlug, srcChainSlug);
  const siblingPlug = plugConfig.siblingPlug;

  console.log(`  Sibling Plug: ${siblingPlug}\n`);

  // Pack message for signature
  const packedMessage = await hasherContract.packMessage(
    srcChainSlug,
    siblingPlug,
    destinationChain,
    dstPlug,
    [
      EXECUTION_CONFIG.messageDetails.msgId,
      EXECUTION_CONFIG.messageDetails.executionFee,
      EXECUTION_CONFIG.messageDetails.minMsgGasLimit,
      EXECUTION_CONFIG.messageDetails.executionParams,
      EXECUTION_CONFIG.messageDetails.payload,
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
  const signature = await kmsSigner.signMessage(ethers.utils.arrayify(packedMessage));
  console.log("Signature:", signature);

  // Prepare transaction structs
  const executionDetails = {
    packetId: EXECUTION_CONFIG.executionDetails.packetId,
    proposalCount: EXECUTION_CONFIG.executionDetails.proposalCount,
    executionGasLimit: EXECUTION_CONFIG.executionDetails.executionGasLimit,
    decapacitorProof: EXECUTION_CONFIG.executionDetails.decapacitorProof,
    signature: signature,
  };

  const messageDetails = {
    msgId: EXECUTION_CONFIG.messageDetails.msgId,
    executionFee: EXECUTION_CONFIG.messageDetails.executionFee,
    minMsgGasLimit: EXECUTION_CONFIG.messageDetails.minMsgGasLimit,
    executionParams: EXECUTION_CONFIG.messageDetails.executionParams,
    payload: EXECUTION_CONFIG.messageDetails.payload,
  };

  // Prepare transaction data
  const socketInterface = new ethers.utils.Interface(SocketArtifact.abi);
  const calldata = socketInterface.encodeFunctionData("execute", [
    executionDetails,
    messageDetails,
  ]);

  console.log("\n=== Transaction Details ===");
  console.log(`Chain ID: ${(await provider.getNetwork()).chainId}`);
  console.log(`Target: ${socketAddress}`);
  console.log(`Value: ${EXECUTION_CONFIG.msgValue}`);
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
        value: EXECUTION_CONFIG.msgValue,
        ...(await getOverrides(destinationChain, provider)),
      }
    );

    console.log("Transaction hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed in block:", receipt.blockNumber);
    console.log("Gas used:", receipt.gasUsed.toString());
  } else {
    console.log("To send the execute transaction, add --sendtx flag");
    console.log("You can use the transaction details above to manually send, simulate, or audit the transaction.");
  }

  console.log("\nScript completed.");
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
