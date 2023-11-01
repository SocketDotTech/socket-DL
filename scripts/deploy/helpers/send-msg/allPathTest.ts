import { config as dotenvConfig } from "dotenv";
import axios from "axios";

dotenvConfig();
import {
  ChainSlug,
  TestnetIds,
  MainnetIds,
  isTestnet,
  isMainnet,
  CORE_CONTRACTS,
} from "../../../../src";
import { getAddresses, getRelayUrl, getRelayAPIKEY } from "../../utils";
import { BigNumber, Contract, ethers } from "ethers";
import Counter from "../../../../out/Counter.sol/Counter.json";
import Socket from "../../../../out/Socket.sol/Socket.json";

import { chains, mode } from "../../config";
import { getProviderFromChainSlug } from "../../../constants/networks";

interface RequestObj {
  to: string;
  data: string;
  chainSlug: number;
  value?: string | BigNumber;
  gasPrice?: string | BigNumber;
  gasLimit: number | undefined;
}

const getSiblingSlugs = (chainSlug: ChainSlug): ChainSlug[] => {
  console.log(chainSlug, isMainnet(chainSlug));
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

const axiosPost = async (url: string, data: object, config = {}) => {
  try {
    let response = await axios.post(url, data, config);
    // console.log("txStatus : ", response.status, response.data);
    return { success: true, ...response?.data };
  } catch (error) {
    //@ts-ignore
    console.log("status : ", error?.response?.status);
    console.log(
      "error occurred, url : ",
      url,
      "data : ",
      data,
      config,
      "\n error : ",
      //@ts-ignore
      error?.message,
      //@ts-ignore
      error?.response.data
    );
    //@ts-ignore
    return { success: false, ...error?.response?.data };
  }
};

const relayTx = async (params: RequestObj, provider: any) => {
  try {
    let { to, data, chainSlug, gasPrice, value, gasLimit } = params;
    let url = await getRelayUrl(mode);
    let config = {
      headers: {
        "x-api-key": getRelayAPIKEY(mode),
      },
    };
    // console.log({url})
    let body = {
      to,
      data,
      value,
      chainId: (await provider.getNetwork()).chainId,
      gasLimit,
      gasPrice,
      sequential: false,
      source: "LoadTester",
    };
    let response = await axiosPost(url!, body, config);
    if (response?.success) return response?.data;
    else return { hash: "" };
  } catch (error) {
    console.log("uncaught error");
  }
};

export const sendMessagesToAllPaths = async (params: {
  senderChains: ChainSlug[];
  receiverChains: ChainSlug[];
  count: number;
}) => {
  const amount = 100;
  const msgGasLimit = "100000"; // update this when add fee logic for dst gas limit
  let gasLimit: number | undefined = 185766;

  try {
    let { senderChains, receiverChains, count } = params;

    console.log("================= checking for : ", params);
    let activeChainSlugs =
      senderChains.length > 0 ? senderChains : [...MainnetIds, ...TestnetIds];

    // parallelize chains
    await Promise.all(
      activeChainSlugs.map(async (chainSlug) => {
        const siblingSlugs = getSiblingSlugs(chainSlug);
        const addresses = await getAddresses(chainSlug, mode);

        console.log({ chainSlug, siblingSlugs });

        if (!addresses) {
          console.log("addresses not found for ", chainSlug, addresses);
          return;
        }

        // console.log(" 2 ");

        const counterAddress = addresses["Counter"];
        if (!counterAddress) {
          console.log(chainSlug, "counter address not present: ", chainSlug);
          return;
        }
        // console.log(" 3 ");

        const provider = await getProviderFromChainSlug(chainSlug);
        const socket: Contract = new ethers.Contract(
          addresses[CORE_CONTRACTS.Socket],
          Socket.abi,
          provider
        );

        const counter: Contract = new ethers.Contract(
          counterAddress,
          Counter.abi
        );

        await Promise.all(
          siblingSlugs.map(async (siblingSlug) => {
            if (
              receiverChains.length > 0 &&
              !receiverChains.includes(siblingSlug)
            )
              return;

            // value = 100
            let executionParams =
              "0x0100000000000000000000000000000000000000000000000000000000000064";
            let transmissionParams =
              "0x0000000000000000000000000000000000000000000000000000000000000000";
            let data = counter.interface.encodeFunctionData(
              "remoteAddOperation",
              [
                siblingSlug,
                amount,
                msgGasLimit,
                // executionParams,
                ethers.constants.HashZero,
                ethers.constants.HashZero,
              ]
            );
            let to = counter.address;
            let value = await socket.getMinFees(
              msgGasLimit,
              100, // payload size
              executionParams,
              transmissionParams,
              siblingSlug,
              to
            );

            console.log(`fees is ${value}`);

            gasLimit =
              chainSlug === ChainSlug.ARBITRUM ||
              chainSlug === ChainSlug.ARBITRUM_GOERLI
                ? undefined
                : gasLimit;

            let tempArray = new Array(count).fill(1);
            await Promise.all(
              tempArray.map(async (c) => {
                // console.log(c)
                let response = await relayTx(
                  {
                    to,
                    data,
                    value,
                    gasLimit,
                    chainSlug,
                  },
                  provider
                );
                console.log(
                  `Tx sent : ${chainSlug} -> ${siblingSlug} hash: `,
                  response?.hash
                );
              })
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
  let senderChains = chains;
  let receiverChains = chains;
  let count = 1;
  await sendMessagesToAllPaths({ senderChains, receiverChains, count });
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// npx ts-node scripts/deploy/scripts/allPathTest.ts
