import hre from "hardhat";
import { ethers, run } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

/**
 * Deploys network-independent gas-price-oracle contracts
 */
export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner, counterOwner } = await getNamedAccounts();
    
    //0xF883Bb6FbDcea8664e37F2f572f6659CE1AcE75A
    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(
      counterOwner
    );

    const factory = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleContract = await factory.deploy(socketSigner.address);
    await gasPriceOracleContract.deployed();

    await sleep(30);

    await run("verify:verify", {
      address: gasPriceOracleContract.address,
      contract: `contracts/GasPriceOracle.sol:GasPriceOracle`,
      constructorArguments: [socketSigner.address],
    });

    const tx = await gasPriceOracleContract
        .connect(socketSigner)
        .setTransmitManager(socketOwner);

      console.log(`Setting transmit manager in oracle: ${tx.hash}`);

      await tx.wait();
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
