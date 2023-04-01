import { constants } from "ethers";
import { chainSlugs } from "../../constants";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const confirmGasLimit = 300000;

export const arbitrumL2Switchboard = (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "ArbitrumL2Switchboard",
    args: [
      chainSlugs[network],
      confirmGasLimit,
      initiateGasLimit,
      executionOverhead,
      signerAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/ArbitrumL2Switchboard.sol",
  };
};
