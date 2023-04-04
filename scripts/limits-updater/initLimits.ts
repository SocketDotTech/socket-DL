import { Contract, Signer } from "ethers";
import {
  attestGasLimit,
  chainSlugs,
  executionOverhead,
  proposeGasLimit,
} from "../constants";
import { getSigner } from "./relayer.config";
import { ChainSocketAddresses } from "../../src/types";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import * as OptimisticSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/OptimisticSwitchboard.sol/OptimisticSwitchboard.json";
import * as TransmitManagerABI from "../../artifacts/contracts/TransmitManager.sol/TransmitManager.json";
import {
  getAddresses,
  getChainSlugsFromDeployedAddresses,
} from "../deploy/utils";

export const setLimitsForAChainSlug = async (
  chainSlug: keyof typeof chainSlugs
) => {
  try {
    const chainId = chainSlugs[chainSlug];
    console.log(
      `setting initLimits for chain: ${chainSlug} and chainId: ${chainId}`
    );

    //const deployedAddressConfig: ChainSocketAddresses = await getAddresses(chainId);
    // const localChain = "arbitrum-goerli";

    // if (!fs.existsSync(deployedAddressPath)) {
    //   throw new Error("addresses.json not found");
    // }
    // const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));

    // const deployedAddressConfig: ChainSocketAddresses =
    //   addresses[chainSlugs[localChain]];

    const deployedAddressConfig: ChainSocketAddresses = await getAddresses[
      chainId
    ];

    console.log(
      `for chainSlugCode: ${chainSlug} , looked-up deployedAddressConfigs: ${JSON.stringify(
        deployedAddressConfig
      )}`
    );

    const signer: Signer = getSigner(chainId);

    const integrations = deployedAddressConfig.integrations;

    for (let integration in integrations) {
      console.log(`integration is: ${JSON.stringify(integration)}`);

      //if(integration.)
    }

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
    const executionOverheadValue = executionOverhead[chainSlug];

    //TODO set AttestGasLimit in OptimisticSwitchboard
    const attestGasLimitValue = attestGasLimit[chainSlug];

    //get TransmitManager Address
    const transmitManagerAddress =
      deployedAddressConfig.TransmitManager as string;

    const transmitManherInstance: Contract = new Contract(
      transmitManagerAddress,
      TransmitManagerABI.abi,
      signer
    );

    //TODO set ProposeGasLimit in TransmitManager
    const proposeGasLimitValue = proposeGasLimit[chainSlug];
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

// npx ts-node scripts/deploy/initLimits.ts
export const setLimits = async () => {
  try {
    const chainSlugsDecoded: string[] =
      (await getChainSlugsFromDeployedAddresses()) as string[];

    for (let chainSlugCode in chainSlugsDecoded) {
      setLimitsForAChainSlug(chainSlugCode as keyof typeof chainSlugs);
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

setLimits()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
