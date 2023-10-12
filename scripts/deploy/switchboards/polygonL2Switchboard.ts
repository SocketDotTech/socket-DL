import { ChainSlug } from "../../../src/types";
import { bridgeConsts } from "../../constants";

export const polygonL2Switchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL2Switchboard",
    args: [
      chainSlug,
      bridgeConsts.fxChild[chainSlug],
      signerAddress,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/PolygonL2Switchboard.sol",
  };
};
