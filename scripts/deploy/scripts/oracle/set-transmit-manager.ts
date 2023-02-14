import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/set-transmit-manager.ts --network goerli
export const setTransmitManagerInGasPriceOracle = async () => {
  try {

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const gasPriceOracleAddress = '0x3ECc6604bB808f4eEE4A78400A5DCd3Eb3A2148A';
    const GasPriceOracle = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleInstance = GasPriceOracle.attach(gasPriceOracleAddress);

    const transmitManagerAddress = '0xD670A70781CB24F4525536cEa0cb7639635c9a87';
    const tx = await gasPriceOracleInstance.connect(socketOwnerSigner).setTransmitManager(
      transmitManagerAddress,
      {
        gasLimit: 50000,
        gasPrice: ethers.utils.parseUnits("50", "gwei").toNumber()
      });
    await tx.wait();
  } catch (error) {
    console.log("Error in setTransmitManagerInGasPriceOracle", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  setTransmitManagerInGasPriceOracle()
  .then(() => {
    console.log("✅ finished running the setTransmitManagerInGasPriceOracle.");
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });