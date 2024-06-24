require("dotenv").config();
import { BigNumber, Contract, providers } from "ethers";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  DeploymentMode,
  MainnetIds,
  TestnetIds,
  getAllAddresses,
} from "../../../src";
import prompts from "prompts";
import { getJsonRpcUrl } from "../../constants";
import SocketABI from "../../../artifacts/contracts/socket/SocketBase.sol/SocketBase.json";
import EMABI from "../../../artifacts/contracts/ExecutionManager.sol/ExecutionManager.json";
import EMDFABI from "../../../artifacts/contracts/ExecutionManagerDF.sol/ExecutionManagerDF.json";
import { getSiblings } from "../utils";

const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
const addresses: DeploymentAddresses = getAllAddresses(deploymentMode);

const checkEM = async (
  socketAddress: string,
  expectedEMAddress: string,
  chain: ChainSlug,
  provider: providers.JsonRpcProvider
) => {
  // Create a contract instance
  const socketContract = new Contract(socketAddress, SocketABI.abi, provider);
  const em = await socketContract.executionManager__();
  if (expectedEMAddress.toLowerCase() != em.toLowerCase())
    console.log(`❌ EM not matching for ${chain}`);

  console.log(`✅ EM matching for ${chain}`);
};

const checkEMFees = async (
  chain: ChainSlug,
  chainAddresses: ChainSocketAddresses,
  provider: providers.JsonRpcProvider
) => {
  // Create a contract instance
  const emContract = new Contract(
    chainAddresses.ExecutionManager,
    EMABI.abi,
    provider
  );
  const siblings = getSiblings(chainAddresses);

  await Promise.all(
    siblings.map(async (sibling) => {
      const fees = await emContract.executionFees(sibling);
      if (fees != 0) console.log(`✅ EM fees set for pair ${chain}-${sibling}`);

      console.log(`❌ EM fees set to 0 for pair ${chain}-${sibling}, ${fees}`);
    })
  );
};

const checkEMDFFees = async (
  chain: ChainSlug,
  chainAddresses: ChainSocketAddresses,
  provider: providers.JsonRpcProvider
) => {
  // Create a contract instance
  const emContract = new Contract(
    chainAddresses.ExecutionManagerDF,
    EMDFABI.abi,
    provider
  );
  const siblings = getSiblings(chainAddresses);

  await Promise.all(
    siblings.map(async (sibling) => {
      const fees = await emContract.executionFees(sibling);

      if (fees.gasPrice.eq(BigNumber.from(0)))
        console.log(`❌ EM fees set to 0 for pair ${chain}-${sibling}: {
        gasPrice: ${fees.gasPrice},
        perByteCost: ${fees.perByteCost},
        overhead: ${fees.overhead}
      }`);

      console.log(`✅ EM fees set for pair ${chain}-${sibling}`);
    })
  );
};

const runTests = async (emVersion: string, chains: ChainSlug[]) => {
  try {
    for (let index = 0; index < chains.length; index++) {
      const provider = new providers.JsonRpcProvider(
        getJsonRpcUrl(chains[index])
      );
      const chainAddresses = addresses[chains[index]];
      if (!chainAddresses) throw new Error("Addresses not found");

      // check if correct version set in socket
      await checkEM(
        chainAddresses.Socket,
        chainAddresses[emVersion],
        chains[index],
        provider
      );

      // get fees and check if its non zero and display on terminal
      if (emVersion === CORE_CONTRACTS.ExecutionManagerDF) {
        await checkEMDFFees(chains[index], chainAddresses, provider);
      } else {
        await checkEMFees(chains[index], chainAddresses, provider);
      }
    }
  } catch (error) {
    console.log("Error:", error);
  }
};

const main = async () => {
  const response = await prompts([
    {
      name: "chainType",
      type: "select",
      message: "Select chains network type",
      choices: [
        {
          title: "Mainnet",
          value: "mainnet",
        },
        {
          title: "Testnet",
          value: "testnet",
        },
      ],
    },
  ]);

  const chainOptions =
    response.chainType === "mainnet" ? MainnetIds : TestnetIds;
  let choices = chainOptions.map((chain) => ({
    title: chain.toString(),
    value: chain,
  }));

  const configResponse = await prompts([
    {
      name: "chains",
      type: "multiselect",
      message: "Select sibling chains to connect",
      choices,
    },
    {
      name: "emVersion",
      type: "select",
      message: "Select execution manager version to perform check on",
      choices: [
        {
          title: "Execution Manager DF",
          value: CORE_CONTRACTS.ExecutionManagerDF,
        },
        {
          title: "Execution Manager",
          value: CORE_CONTRACTS.ExecutionManager,
        },
      ],
    },
  ]);

  await runTests(configResponse.emVersion, configResponse.chains);
};

main();
