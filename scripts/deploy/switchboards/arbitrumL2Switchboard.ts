import { ChainSlug } from "../../../src";

export const arbitrumL2Switchboard = (
  chainSlug: ChainSlug,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL2Switchboard",
    args: [chainSlug, signerAddress, socketAddress, sigVerifierAddress],
    path: "contracts/switchboard/native/ArbitrumL2Switchboard.sol",
  };
};
