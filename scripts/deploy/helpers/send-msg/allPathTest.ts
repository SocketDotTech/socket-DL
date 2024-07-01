import { config as dotenvConfig } from "dotenv";
dotenvConfig();
import {
  ChainSlug,
  MainnetIds,
  TestnetIds,
  isMainnet,
  isTestnet,
} from "../../../../src";
import { sendCounterBridgeMsg } from "./utils";

const getSiblingSlugs = (chainSlug: ChainSlug): ChainSlug[] => {
  if (isTestnet(chainSlug))
    return TestnetIds.filter(
      (siblingChainSlug) => chainSlug !== siblingChainSlug
    );
  if (isMainnet(chainSlug))
    return MainnetIds.filter(
      (siblingChainSlug) => chainSlug !== siblingChainSlug
    );
  return [];
};

const config = {
  msgGasLimit: "200000",
  payloadSize: 100, // for counter add operation
  executionParams:
    "0x0000000000000000000000000000000000000000000000000000000000000000",
  transmissionParams:
    "0x0000000000000000000000000000000000000000000000000000000000000000",
};

export const sendMessagesToAllPaths = async (params: {
  senderChains: ChainSlug[];
  receiverChains: ChainSlug[];
}) => {
  try {
    let { senderChains, receiverChains } = params;

    console.log("================= checking for : ", params);
    let activeChainSlugs =
      senderChains.length > 0 ? senderChains : [...MainnetIds, ...TestnetIds];

    // parallelize chains
    await Promise.all(
      activeChainSlugs.map(async (chainSlug) => {
        const siblingSlugs = getSiblingSlugs(chainSlug);
        await Promise.all(
          siblingSlugs.map(async (siblingSlug) => {
            if (
              receiverChains.length > 0 &&
              !receiverChains.includes(siblingSlug)
            )
              return;
            console.log(
              "sending message from ",
              chainSlug,
              " to ",
              siblingSlug
            );
            const {
              payloadSize,
              msgGasLimit,
              executionParams,
              transmissionParams,
            } = config;
            await sendCounterBridgeMsg(
              chainSlug,
              siblingSlug,
              msgGasLimit,
              payloadSize,
              executionParams,
              transmissionParams
            );
          })
        );
      })
    );
  } catch (error) {
    console.log("Error while sending outbound tx", error);
  }
};

const main = async () => {
  let senderChains = [ChainSlug.OPTIMISM_SEPOLIA];
  let receiverChains = [ChainSlug.ARBITRUM_SEPOLIA];
  await sendMessagesToAllPaths({ senderChains, receiverChains });
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// npx ts-node scripts/deploy/helpers/send-msg/allPathTest.ts
