import { constants } from "ethers";
import { ChainId } from "../../../src";
import { bridgeConsts } from "../../constants";
import { getChainId } from "../utils";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const confirmGasLimit = 300000;
const receiveGasLimit = 300000;
const defaultCrossDomainMessengerAddress = '0x5086d1eEF304eb5284A0f6720f79403b4e9bE294';

export const optimismSwitchboard = async (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {

  let crossDomainMessengerAddress : string = bridgeConsts.crossDomainMessenger[network];
  
  if(!crossDomainMessengerAddress || crossDomainMessengerAddress == ''){
    crossDomainMessengerAddress = defaultCrossDomainMessengerAddress;
  }
  
  return {
    contractName: "OptimismSwitchboard",
    args: [
      receiveGasLimit,
      confirmGasLimit,
      initiateGasLimit,
      executionOverhead,
      constants.AddressZero,
      signerAddress,
      oracleAddress,
      crossDomainMessengerAddress,
    ],
    path: "contracts/switchboard/native/OptimismSwitchboard.sol",
  };
};
