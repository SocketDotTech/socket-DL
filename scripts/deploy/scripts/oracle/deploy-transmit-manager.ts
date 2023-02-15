import hre from "hardhat";
import { ethers, run } from "hardhat";

/**
 * Deploys transmitManager contracts
 */
// npx hardhat run scripts/deploy/scripts/oracle/deploy-transmit-manager.ts --network polygon-mumbai
export const main = async () => {
  try {
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();

    const sigVerifier ='0x6cCA0f6485Ab43e9c91E83Be6BFe3A3C0681CC7e';
    const gasPriceOracle = '0xe1C2aE858E8F64be00343aE052F9D3a08856BbB9';
    const owner = socketOwner;
    const chainSlug = 80001;
    const sealGasLimit = 100000;

    // 0xe4813b2Cad4801a0dA640ecDB8b5b059bF5D262b
    const factory = await ethers.getContractFactory('TransmitManager');
    const transmitManagerContract = await factory.deploy(sigVerifier, gasPriceOracle, owner, chainSlug, sealGasLimit);
    await transmitManagerContract.deployed();

    await sleep(30);

    await run("verify:verify", {
      address: transmitManagerContract.address,
      contract: `contracts/TransmitManager.sol:TransmitManager`,
      constructorArguments: [sigVerifier, gasPriceOracle, owner, chainSlug, sealGasLimit],
    });

  } catch (error) {
    console.log("Error in deploying TransmitManager contracts", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

  export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));
