import { sendCounterBridgeMsg } from "./utils";
import { ChainSlug } from "../../../../src";

const config = {
  chainSlug: ChainSlug.OPTIMISM_SEPOLIA,
  siblingSlug: ChainSlug.ARBITRUM_SEPOLIA,
  msgGasLimit: "200000",
  payloadSize: 100, // for counter add operation
  executionParams:
    "0x0000000000000000000000000000000000000000000000000000000000000000",
};

const transmissionParams = [
  "0x0101000000010000000000000000000000000000000000000000000000000000",
  "0x0101000000020000000000000000000000000000000000000000000000000000",
  "0x0101000000030000000000000000000000000000000000000000000000000000",
];
const sendMsgsWithVaryingParams = async () => {
  for (const param of transmissionParams) {
    try {
      const {
        msgGasLimit,
        payloadSize,
        executionParams,
        chainSlug,
        siblingSlug,
      } = config;
      console.log(
        `\n\n Sending message with transmission params: ${JSON.stringify(
          param
        )}`
      );
      await sendCounterBridgeMsg(
        chainSlug,
        siblingSlug,
        msgGasLimit,
        payloadSize,
        executionParams,
        param
      );
      console.log(
        `Message sent with transmission params: ${JSON.stringify(param)}`
      );
    } catch (error) {
      console.error(
        `Failed to send message with transmission params: ${JSON.stringify(
          param
        )}`
      );
      console.error(error);
    }
  }
};

sendMsgsWithVaryingParams();

// usage:
// npx ts-node scripts/deploy/helpers/send-msg/transmissionParamsTestScript.ts
