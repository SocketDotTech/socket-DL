import hre from "hardhat";
import { ethers, run } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

/**
 * Deploys network-independent gas-price-oracle contracts
 */
// npx hardhat run scripts/deploy/scripts/oracle/deploy-gasprice-oracle.ts --network polygon-mumbai
export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();
    
    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);

    const factory = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleContract = await factory.deploy(socketSigner.address, 80001);
    await gasPriceOracleContract.deployed();

    await sleep(30);

        // 0xe1C2aE858E8F64be00343aE052F9D3a08856BbB9
    await run("verify:verify", {
      address: gasPriceOracleContract.address,
      contract: `contracts/GasPriceOracle.sol:GasPriceOracle`,
      constructorArguments: [socketSigner.address, 80001],
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
