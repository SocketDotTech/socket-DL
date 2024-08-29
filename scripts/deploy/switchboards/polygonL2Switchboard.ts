import { ChainSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

export const polygonL2Switchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  owner: string
) => {
  return {
    contractName: "PolygonL2Switchboard",
    args: [
      chainSlug,
      bridgeConsts.fxChild[chainSlug],
      owner,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/PolygonL2Switchboard.sol",
  };
};
