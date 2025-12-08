import { config as dotenvConfig } from "dotenv";
import {
  ChainSlug,
  DeploymentAddresses,
  IntegrationTypes,
  getAllAddresses,
} from "../../src";
import { mode, overrides } from "../deploy/config/config";
import FastSwitchboardArtifact from "../../out/FastSwitchboard.sol/FastSwitchboard.json";
import { getProviderFromChainSlug } from "../constants";
import { ethers, Wallet } from "ethers";
import { defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { getAwsKmsSigner } from "@socket.tech/dl-common";

dotenvConfig();

/**
 * Usage
 *
 * --source         Specify the source chain slug.
 *                  This flag is required.
 *                  Eg. npx --source=1 --destination=10 --packetid=0x... --proposalcount=1 --root=0x... --kmskeyid=abc-123 ts-node scripts/admin/send-attest.ts
 *
 * --destination    Specify the destination chain slug.
 *                  This flag is required.
 *
 * --packetid       Specify the packet ID.
 *                  This flag is required.
 *
 * --proposalcount  Specify the proposal count.
 *                  This flag is required.
 *
 * --root           Specify the root hash.
 *                  This flag is required.
 *
 * --kmskeyid       Specify the AWS KMS key ID.
 *                  This flag is required.
 *
 * --sendtx         Send attest tx along with signature generation.
 *                  Default is only generate and display signature.
 *                  Eg. npx  --source=1 --destination=10 --packetid=0x... --proposalcount=1 --root=0x... --kmskeyid=abc-123 --sendtx ts-node scripts/admin/send-attest.ts
 */

const sourceChainSlug = process.env.npm_config_source;
if (!sourceChainSlug) {
  console.error("Error: source flag is required");
  process.exit(1);
}

const destinationChainSlug = process.env.npm_config_destination;
if (!destinationChainSlug) {
  console.error("Error: destination flag is required");
  process.exit(1);
}

const packetId = process.env.npm_config_packetid;
if (!packetId) {
  console.error("Error: packetid flag is required");
  process.exit(1);
}

const proposalCount = process.env.npm_config_proposalcount;
if (!proposalCount) {
  console.error("Error: proposalcount flag is required");
  process.exit(1);
}

const root = process.env.npm_config_root;
if (!root) {
  console.error("Error: root flag is required");
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
  const sourceChain = sourceChainSlug;
  const destinationChain = destinationChainSlug;

  console.log(`\nProcessing attest for path: ${sourceChain} -> ${destinationChain}\n`);

  // Get addresses from prod_addresses.json
  const destinationAddresses = addresses[destinationChain];
  if (!destinationAddresses) {
    console.error(
      `Error: No addresses found for destination chain ${destinationChain}`
    );
    process.exit(1);
  }

  const integration = destinationAddresses.integrations?.[sourceChain];
  if (!integration) {
    console.error(
      `Error: No integration found for ${destinationChain} -> ${sourceChain}`
    );
    process.exit(1);
  }

  // Get FAST integration switchboard
  const fastIntegration = integration[IntegrationTypes.fast];
  if (!fastIntegration) {
    console.error(
      `Error: No FAST integration found for ${destinationChain} -> ${sourceChain}`
    );
    process.exit(1);
  }

  const switchboardAddress = fastIntegration.switchboard;

  console.log("Addresses:");
  console.log(`  Switchboard: ${switchboardAddress}\n`);

  // Get provider
  const provider = getProviderFromChainSlug(
    parseInt(destinationChain) as ChainSlug
  );

  // Get AWS KMS signer
  console.log("Getting AWS KMS signer...");
  const kmsSigner = (await getAwsKmsSigner(kmsKeyId)).connect(provider);
  const kmsAddress = await kmsSigner.getAddress();
  console.log(`KMS Address: ${kmsAddress}\n`);

  // Prepare message hash for signing
  const messageHash = keccak256(
    defaultAbiCoder.encode(
      ["address", "uint32", "bytes32", "uint256", "bytes32"],
      [switchboardAddress, parseInt(destinationChain), packetId, proposalCount, root]
    )
  );

  console.log("Message hash:", messageHash);

  // Sign with KMS
  console.log("\nSigning with AWS KMS...");
  const signature = await kmsSigner.signMessage(ethers.utils.arrayify(messageHash));
  console.log("Signature:", signature);

  // Prepare transaction data
  const switchboardInterface = new ethers.utils.Interface(FastSwitchboardArtifact.abi);
  const calldata = switchboardInterface.encodeFunctionData("attest", [
    packetId,
    proposalCount,
    root,
    signature,
  ]);

  console.log("\n=== Transaction Details ===");
  console.log(`Chain ID: ${(await provider.getNetwork()).chainId}`);
  console.log(`Target: ${switchboardAddress}`);
  console.log(`Value: 0`);
  console.log(`Calldata: ${calldata}`);
  console.log("===========================\n");

  if (sendTx) {
    console.log("Sending attest transaction...");

    const wallet = new Wallet(signerKey!, provider);

    const switchboardContract = new ethers.Contract(
      switchboardAddress,
      FastSwitchboardArtifact.abi,
      wallet
    );

    const tx = await switchboardContract.attest(
      packetId,
      proposalCount,
      root,
      signature,
      {
        ...(await overrides(parseInt(destinationChain))),
      }
    );

    console.log("Transaction hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("Transaction confirmed in block:", receipt.blockNumber);
    console.log("Gas used:", receipt.gasUsed.toString());
  } else {
    console.log("To send the attest transaction, add --sendtx flag");
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
