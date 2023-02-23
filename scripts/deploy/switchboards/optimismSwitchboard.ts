import { constants } from "ethers";

const executionOverhead = 300000
const initialConfirmationGasLimit = 300000
const l2ReceiveGasLimit = 300000
const receivePacketGasLimit = 300000

export const optimismSwitchboard = (oracleAddress: string, signerAddress: string) => {
  return { contractName: "OptimismSwitchboard", args: [receivePacketGasLimit, l2ReceiveGasLimit, initialConfirmationGasLimit, executionOverhead, constants.AddressZero, signerAddress, oracleAddress], path: "contracts/switchboard/native/OptimismSwitchboard.sol" };
};
