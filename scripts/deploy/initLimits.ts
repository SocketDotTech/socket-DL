import { Contract, Signer } from "ethers";
import { StaticJsonRpcProvider } from "@ethersproject/providers";
import { DefenderRelaySigner } from "defender-relay-client/lib/ethers";
import { config } from "./config";
import { getAddresses } from "./utils";
import { chainSlugs } from "../constants";
import { ChainId, loadRelayerConfigs } from "./utils/relayer.config";
import { RelayerConfig, relayTxSpeed } from "./utils/types";
import { ChainSocketAddresses } from "../../src/types";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import * as OptimisticSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol/OptimisticSwitchboard.json";
import * as TransmitManagerABI from "../../artifacts/contracts/TransmitManager.sol/TransmitManager.json";

export const main = async () => {
  try {
    const relayerConfigs: Map<ChainId, RelayerConfig> = loadRelayerConfigs();

    for (let chain in config) {
      console.log(`setting initLimits for chain: ${chain}`);
      const chainId = chainSlugs[chain];
      const deployedAddressConfig: ChainSocketAddresses = await getAddresses(
        chainId
      );
      console.log(
        `for chain: ${chain} , looked-up deployedAddressConfigs: ${JSON.stringify(
          deployedAddressConfig
        )}`
      );

      //get RelayerConfig for the chainId
      const relayerConfig: RelayerConfig = relayerConfigs.get(
        chainId
      ) as RelayerConfig;

      const provider: StaticJsonRpcProvider = new StaticJsonRpcProvider(
        relayerConfig.rpc
      );

      const signer: Signer = new DefenderRelaySigner(
        {
          apiKey: relayerConfig.ozRelayerKey,
          apiSecret: relayerConfig.ozRelayerSecret,
        },
        provider,
        { speed: relayTxSpeed }
      );

      //get fastSwitchBoard Address
      const fastSwitchBoardAddress =
        deployedAddressConfig.FastSwitchboard as string;

      const fastSwitchBoardInstance: Contract = new Contract(
        fastSwitchBoardAddress,
        FastSwitchboardABI.abi,
        signer
      );

      //get Optimistic SwitchBoard Address
      const optimisticSwitchBoardAddress =
        deployedAddressConfig.OptimisticSwitchboard as string;

      const optimisticSwitchBoardInstance: Contract = new Contract(
        optimisticSwitchBoardAddress,
        OptimisticSwitchboardABI.abi,
        signer
      );

      //TODO set ExecutionOverhead in OptimisticSwitchboard

      //TODO set AttestGasLimit in OptimisticSwitchboard

      //get TransmitManager Address
      const transmitManagerAddress =
        deployedAddressConfig.TransmitManager as string;

      const transmitManherInstance: Contract = new Contract(
        transmitManagerAddress,
        TransmitManagerABI.abi,
        signer
      );

      //TODO set ProposeGasLimit in TransmitManager
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
