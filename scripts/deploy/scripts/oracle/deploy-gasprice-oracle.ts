import hre from "hardhat";
import { ethers, run } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

/**
 * Deploys network-independent gas-price-oracle contracts
 */
// npx hardhat run scripts/deploy/scripts/oracle/deploy-gasprice-oracle.ts --network goerli
export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();
    
    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);

    const factory = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleContract = await factory.deploy(socketSigner.address, 5);
    await gasPriceOracleContract.deployed();

    await sleep(30);

        // 0x3ECc6604bB808f4eEE4A78400A5DCd3Eb3A2148A
    await run("verify:verify", {
      address: gasPriceOracleContract.address,
      contract: `contracts/GasPriceOracle.sol:GasPriceOracle`,
      constructorArguments: [socketSigner.address, 5],
    });

    // const tx = await gasPriceOracleContract
    //     .connect(socketSigner)
    //     .setTransmitManager(socketOwner);

    //   console.log(`Setting transmit manager in oracle: ${tx.hash}`);

    // await tx.wait();
  } catch (error) {
    console.log("Error in deploying gasprice-oracle contracts", error);
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
