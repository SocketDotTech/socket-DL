import { ChainSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

export const polygonL1Switchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL1Switchboard",
    args: [
      chainSlug,
      bridgeConsts.checkpointManager[chainSlug],
      bridgeConsts.fxRoot[chainSlug],
      signerAddress,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/PolygonL1Switchboard.sol",
  };
};
