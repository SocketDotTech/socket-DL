import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/set-transmit-manager.ts --network polygon-mumbai
export const setTransmitManagerInGasPriceOracle = async () => {
  try {

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const gasPriceOracleAddress = '0xe1C2aE858E8F64be00343aE052F9D3a08856BbB9';
    const GasPriceOracle = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleInstance = GasPriceOracle.attach(gasPriceOracleAddress);

    const transmitManagerAddress = '0xe4813b2Cad4801a0dA640ecDB8b5b059bF5D262b';
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