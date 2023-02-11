import { constants } from "ethers";

const executionOverhead = 300000
const initialConfirmationGasLimit = 300000
const l1ReceiveGasLimit = 300000

export const arbitrumL2Switchboard = (
  oracleAddress: string,
  signerAddress: string
) => {
  return { contractName: "ArbitrumL2Switchboard", args: [l1ReceiveGasLimit, initialConfirmationGasLimit, executionOverhead, constants.AddressZero, signerAddress, oracleAddress], path: "contracts/switchboard/native/ArbitrumL2Switchboard.sol" };
};
