import { BigNumber } from "ethers";
import { getRelayAPIKEY, getRelayUrl } from "./utils";
import { axiosPost } from "@socket.tech/dl-common";
import { mode } from "../config/config";
import { ChainSlugToId } from "@socket.tech/dl-core";

interface RequestObj {
  to: string;
  data: string;
  chainSlug: number;
  value?: string | BigNumber;
  gasPrice?: string | BigNumber | undefined;
  gasLimit: string | number | undefined;
}

export const relayTx = async (params: RequestObj) => {
  try {
    let { to, data, chainSlug, gasPrice, value, gasLimit } = params;
    let url = await getRelayUrl(mode);
    let config = {
      headers: {
        "x-api-key": getRelayAPIKEY(mode),
      },
    };
    let body = {
      to,
      data,
      value,
      chainId: ChainSlugToId[chainSlug],
      gasLimit,
      gasPrice,
      sequential: false,
      source: "LoadTester",
    };
    let response = await axiosPost(url!, body, config);
    if (response?.success) return response?.data;
    else {
      console.log("error in relaying tx", response);
      return { hash: "" };
    }
  } catch (error) {
    console.log("uncaught error", error);
  }
};
