import { config as dotenvConfig } from "dotenv";
import {
  ChainSlug,
  DeploymentAddresses,
  IntegrationTypes,
  getAllAddresses,
} from "../../src";
import { mode } from "../deploy/config/config";
import SingleCapacitorArtifact from "../../out/SingleCapacitor.sol/SingleCapacitor.json";
import { getProviderFromChainSlug } from "../constants";
import { ethers } from "ethers";

dotenvConfig();

/**
 * Usage
 *
 * --source         Specify the source chain slug.
 *                  This flag is required.
 *                  Eg. npx --source=1 --destination=10 --startblock=12345 --endblock=12456 ts-node scripts/admin/get-outbound-txs.ts
 *
 * --destination    Specify the destination chain slug.
 *                  This flag is required.
 *
 * --startblock     Specify the start block number.
 *                  This flag is required.
 *
 * --endblock       Specify the end block number.
 *                  This flag is required.
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

const startBlock = process.env.npm_config_startblock;
if (!startBlock) {
  console.error("Error: startblock flag is required");
  process.exit(1);
}

const endBlock = process.env.npm_config_endblock;
if (!endBlock) {
  console.error("Error: endblock flag is required");
  process.exit(1);
}

const addresses: DeploymentAddresses = getAllAddresses(mode);

export const main = async () => {
  const sourceChain = sourceChainSlug;
  const destinationChain = destinationChainSlug;

  console.log(`\nProcessing path: ${sourceChain} -> ${destinationChain}\n`);

  // Get addresses from prod_addresses.json
  const sourceAddresses = addresses[sourceChain];
  if (!sourceAddresses) {
    console.error(`Error: No addresses found for source chain ${sourceChain}`);
    process.exit(1);
  }

  const integration = sourceAddresses.integrations?.[destinationChain];
  if (!integration) {
    console.error(
      `Error: No integration found for ${sourceChain} -> ${destinationChain}`
    );
    process.exit(1);
  }

  // Get FAST integration addresses (switchboard, socket, capacitor)
  const fastIntegration = integration[IntegrationTypes.fast];
  if (!fastIntegration) {
    console.error(
      `Error: No FAST integration found for ${sourceChain} -> ${destinationChain}`
    );
    process.exit(1);
  }

  const switchboardAddress = fastIntegration.switchboard;
  const capacitorAddress = fastIntegration.capacitor;
  const socketAddress = sourceAddresses.Socket;

  console.log("Addresses:");
  console.log(`  Switchboard: ${switchboardAddress}`);
  console.log(`  Socket: ${socketAddress}`);
  console.log(`  Capacitor: ${capacitorAddress}\n`);

  // Get provider and query events
  const provider = getProviderFromChainSlug(parseInt(sourceChain) as ChainSlug);

  const capacitorContract = new ethers.Contract(
    capacitorAddress,
    SingleCapacitorArtifact.abi,
    provider
  );

  const fromBlock = parseInt(startBlock);
  const toBlock = parseInt(endBlock);

  console.log(`Querying events from block ${fromBlock} to ${toBlock}\n`);

  // Query MessageAdded events in chunks of 5000 blocks
  const CHUNK_SIZE = 5000;
  const messageAddedEvents = [];

  for (
    let currentBlock = fromBlock;
    currentBlock <= toBlock;
    currentBlock += CHUNK_SIZE
  ) {
    const chunkEnd = Math.min(currentBlock + CHUNK_SIZE - 1, toBlock);
    console.log(`Querying chunk: ${currentBlock} to ${chunkEnd}`);

    const events = await capacitorContract.queryFilter(
      capacitorContract.filters.MessageAdded(),
      currentBlock,
      chunkEnd
    );

    messageAddedEvents.push(...events);
  }

  console.log(`Found ${messageAddedEvents.length} outbound transactions:\n`);

  for (const event of messageAddedEvents) {
    console.log(`Block: ${event.blockNumber}`);
    console.log(`  Transaction Hash: ${event.transactionHash}`);
    console.log(`  Packed Message: ${event.args?.packedMessage}`);
    console.log(`  Packet Count: ${event.args?.packetCount?.toString()}`);
    console.log(`  Root Hash: ${event.args?.newRootHash}`);
    console.log("");
  }

  console.log("Script completed.");
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
