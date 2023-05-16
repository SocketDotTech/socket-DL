import { config as dotenvConfig } from "dotenv";
import axios from "axios";

dotenvConfig();
import {
  ChainSlug,
  TestnetIds,
  MainnetIds,
  isTestnet,
  isMainnet,
} from "../../../src";
import { getAddresses, getRelayUrl, getRelayAPIKEY } from "../utils";
import { BigNumber, Contract, ethers } from "ethers";
import CounterABI from "@socket.tech/dl-core/artifacts/abi/Counter.json";
import { chains, mode } from "../config";
import { parseUnits } from "ethers/lib/utils";

interface RequestObj {
  to: string;
  data: string;
  chainSlug: number;
  value?: string | BigNumber;
  gasPrice?: string | BigNumber;
  gasLimit: number | undefined;
}

const values: {
  [chainSlug in ChainSlug]?: { [siblingSlug in ChainSlug]?: string };
} = {
  [ChainSlug.ARBITRUM]: {
    [ChainSlug.OPTIMISM]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.POLYGON_MAINNET]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.BSC]: parseUnits("0.003", "ether").toHexString(),
  },
  [ChainSlug.OPTIMISM]: {
    [ChainSlug.ARBITRUM]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.POLYGON_MAINNET]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.BSC]: parseUnits("0.003", "ether").toHexString(),
  },
  [ChainSlug.POLYGON_MAINNET]: {
    [ChainSlug.ARBITRUM]: parseUnits("1", "ether").toHexString(),
    [ChainSlug.OPTIMISM]: parseUnits("1", "ether").toHexString(),
    [ChainSlug.BSC]: parseUnits("1", "ether").toHexString(),
  },
  [ChainSlug.BSC]: {
    [ChainSlug.ARBITRUM]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.OPTIMISM]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.POLYGON_MAINNET]: parseUnits("0.003", "ether").toHexString(),
  },

  // Testnets
  [ChainSlug.ARBITRUM_GOERLI]: {
    [ChainSlug.OPTIMISM_GOERLI]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.POLYGON_MUMBAI]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.BSC_TESTNET]: parseUnits("0.003", "ether").toHexString(),
  },
  [ChainSlug.OPTIMISM_GOERLI]: {
    [ChainSlug.ARBITRUM_GOERLI]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.POLYGON_MUMBAI]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.BSC_TESTNET]: parseUnits("0.003", "ether").toHexString(),
  },
  [ChainSlug.POLYGON_MUMBAI]: {
    [ChainSlug.ARBITRUM_GOERLI]: parseUnits("1", "ether").toHexString(),
    [ChainSlug.OPTIMISM_GOERLI]: parseUnits("1", "ether").toHexString(),
    [ChainSlug.BSC_TESTNET]: parseUnits("1", "ether").toHexString(),
  },
  [ChainSlug.BSC_TESTNET]: {
    [ChainSlug.ARBITRUM_GOERLI]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.OPTIMISM_GOERLI]: parseUnits("0.003", "ether").toHexString(),
    [ChainSlug.POLYGON_MUMBAI]: parseUnits("0.003", "ether").toHexString(),
  },
};

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

const relayTx = async (params: RequestObj) => {
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
      chainId: chainSlug,
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
}) => {
  const amount = 100;
  const msgGasLimit = "100000";
  let gasLimit: number | undefined = 185766;

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
            let value =
              values[chainSlug]?.[siblingSlug] ||
              ethers.utils.parseUnits("3000000", "gwei").toHexString();
            gasLimit =
              chainSlug === ChainSlug.ARBITRUM ||
              chainSlug === ChainSlug.ARBITRUM_GOERLI
                ? undefined
                : gasLimit;
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
  // await sendMessagesToAllPaths({ senderChains, receiverChains });
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
