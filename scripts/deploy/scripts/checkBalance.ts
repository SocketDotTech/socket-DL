import { config as dotenvConfig } from "dotenv";
import axios from "axios";

dotenvConfig();
import {
  ChainSlugToKey,
} from "../../../src";
import {  utils } from "ethers";

import { chains, mode } from "../config";
import { getProviderFromChainName } from "../../constants/networks";

// check balance of owner address on all chains
export const checkBalance = async () => {
  try {
    // parallelize chains
    await Promise.all(
      chains.map(async (chainSlug) => {

        const provider = await getProviderFromChainName(
          ChainSlugToKey[chainSlug]
        );
        // let ownerAddress = process.env.SOCKET_OWNER_ADDRESS;
        let ownerAddress = "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa";
        if (!ownerAddress) throw Error("owner address not present");
        console.log(chainSlug, " ", ChainSlugToKey[chainSlug], " : ", utils.formatEther( await provider.getBalance(ownerAddress)));
        
        
      })
    );
  } catch (error) {
    console.log("Error while checking balance", error);
  }
};

const main = async () => {
  await checkBalance();
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
