import { ChainSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

export const polygonL1Switchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  owner: string
) => {
  return {
    contractName: "PolygonL1Switchboard",
    args: [
      chainSlug,
      bridgeConsts.checkpointManager[chainSlug],
      bridgeConsts.fxRoot[chainSlug],
      owner,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/PolygonL1Switchboard.sol",
  };
};
