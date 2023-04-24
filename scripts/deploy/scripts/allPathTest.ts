import { config as dotenvConfig } from "dotenv";
import axios from "axios";

dotenvConfig();
import {
  ChainSlug,
  TestnetIds,
  MainnetIds,
  isTestnet,
  isMainnet,
  DeploymentMode,
} from "../../../src";
import { getAddresses } from "../utils";
import { BigNumber, Contract, ethers } from "ethers";
import CounterABI from "@socket.tech/dl-core/artifacts/abi/Counter.json";
import { chains, mode } from "../config";

interface RequestObj {
  to: string;
  data: string;
  chainSlug: number;
  value?: string | BigNumber;
  gasPrice?: string | BigNumber;
  gasLimit: number;
}

const getSiblingSlugs = (chainSlug: ChainSlug): ChainSlug[] => {
  if (isTestnet(chainSlug))
    return TestnetIds.filter((chainSlug) => chainSlug !== chainSlug);
  if (isMainnet(chainSlug))
    return MainnetIds.filter((chainSlug) => chainSlug !== chainSlug);
  return [];
};

const axiosPost = async (url, data, config = {}) => {
  try {
    let response = await axios.post(url, data, config);
    // console.log("txStatus : ", response.status, response.data);
    return { success: true, ...response.data };

    //@ts-ignore
  } catch (error) {
    console.log("status : ", error.response.status);
    console.log(
      "error occurred, url : ",
      url,
      "data : ",
      data,
      "\n error : ",
      error.message,
      error.response.data
    );
    return { success: false, ...error.response.data };
  }
};

const relayTx = async (params: RequestObj) => {
  try {
    let { to, data, chainSlug, gasPrice, value, gasLimit } = params;
    const baseUrl =
      "https://9u4hhxgtyi.execute-api.us-east-1.amazonaws.com/dev/v1";
    let url = baseUrl + "/relayTx";
    let body = {
      to,
      data,
      value,
      chainSlug,
      gasLimit,
      gasPrice,
      sequential: false,
      source: "LoadTester",
    };
    let response = await axiosPost(url, body);
    if (response?.success) return response?.data;
    else return { hash: "" };
  } catch (error) {
    console.log("uncaught error");
  }
};

export const sendMessagesToAllPaths = async (params: {
  senderChains: ChainSlug[];
  receiverChains: ChainSlug[];
}) => {
  const amount = 100;
  const msgGasLimit = "100000";
  const gasLimit = 185766;

  try {
    let { senderChains, receiverChains } = params;

    console.log("================= checking for : ", params);
    let activeChainSlugs =
      senderChains.length > 0 ? senderChains : [...MainnetIds, ...TestnetIds];

    // parallelize chains
    await Promise.all(
      activeChainSlugs.map(async (chainSlug) => {
        let siblingSlugs = getSiblingSlugs(chainSlug);
        let addresses = await getAddresses(chainSlug, mode);

        if (!addresses) return;

        const counterAddress = addresses["Counter"];
        if (!counterAddress) {
          console.log(chainSlug, "counter address not present: ", chainSlug);
          return;
        }

        const counter: Contract = new ethers.Contract(
          counterAddress,
          CounterABI
        );

        await Promise.all(
          siblingSlugs.map(async (siblingSlug) => {
            if (
              receiverChains.length > 0 &&
              !receiverChains.includes(siblingSlug)
            )
              return;

            let data = counter.interface.encodeFunctionData(
              "remoteAddOperation",
              [siblingSlug, amount, msgGasLimit]
            );
            let to = counter.address;
            let value = ethers.utils.parseUnits("3000000", "gwei").toString();

            let response = await relayTx({
              to,
              data,
              value,
              gasLimit,
              chainSlug,
            });
            console.log(
              `Tx sent : ${chainSlug} -> ${siblingSlug} hash: `,
              response?.hash
            );
          })
        );
      })
    );
  } catch (error) {
    console.log("Error while checking roles", error);
    throw error;
  }
};

const main = async () => {
  let senderChains = chains;
  let receiverChains = chains;
  await sendMessagesToAllPaths({ senderChains, receiverChains });
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
