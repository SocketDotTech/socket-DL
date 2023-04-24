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
const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;

interface RequestObj {
  to: string;
  data: string;
  chainId: number;
  value?: string | BigNumber;
  gasPrice?: string | BigNumber;
  gasLimit: number;
}

const getSiblingSlugs = (chainId: ChainSlug): ChainSlug[] => {
  if (isTestnet(chainId))
    return TestnetIds.filter((chainSlug) => chainSlug !== chainId);
  if (isMainnet(chainId))
    return MainnetIds.filter((chainSlug) => chainSlug !== chainId);
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
    let { to, data, chainId, gasPrice, value, gasLimit } = params;
    // const baseUrl = "http://localhost:3000/v1"; // localhost
    const baseUrl =
      "https://9u4hhxgtyi.execute-api.us-east-1.amazonaws.com/dev/v1";
    let url = baseUrl + "/relayTx";
    let body = {
      to,
      data,
      value,
      chainId,
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
      activeChainSlugs.map(async (chainId) => {
        let siblingSlugs = getSiblingSlugs(chainId);

        let addresses = await getAddresses(chainId, mode);

        if (!addresses) return;

        // const counterAddress = config[chainSlug]["Counter"];
        const counterAddress = "0xefc0c02abca8dda7d2b399d5c41358cc8ff0a183"; // check this

        if (!counterAddress) {
          console.log(chainId, "counter address not present: ", chainId);
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
            let value = ethers.utils.parseUnits("30000", "gwei").toString();
            let response = await relayTx({
              to,
              data,
              value,
              gasLimit,
              chainId,
            });
            console.log(
              `Tx sent : ${chainId} -> ${siblingSlug} hash: `,
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
  let senderChains = [ChainSlug.MUMBAI];
  let receiverChains = TestnetIds;
  await sendMessagesToAllPaths({ senderChains, receiverChains });
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
