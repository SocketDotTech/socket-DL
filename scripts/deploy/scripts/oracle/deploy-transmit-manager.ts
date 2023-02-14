import hre from "hardhat";
import { ethers, run } from "hardhat";

/**
 * Deploys transmitManager contracts
 */
// npx hardhat run scripts/deploy/scripts/oracle/deploy-transmit-manager.ts --network goerli
export const main = async () => {
  try {
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();

    const sigVerifier ='0x98d36cf40f46A5fD51C26AC53390C26b87ff9E1F';
    const gasPriceOracle = '0x3ECc6604bB808f4eEE4A78400A5DCd3Eb3A2148A';
    const owner = socketOwner;
    const chainSlug = 5;
    const sealGasLimit = 100000;

    // 0xD670A70781CB24F4525536cEa0cb7639635c9a87
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
