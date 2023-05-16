import { chainKeyToSlug } from "../../../src";

export const arbitrumL2Switchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL2Switchboard",
    args: [
      chainKeyToSlug[network],
      signerAddress,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/ArbitrumL2Switchboard.sol",
  };
};
