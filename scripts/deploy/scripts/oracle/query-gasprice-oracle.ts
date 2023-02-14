import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/query-gasprice-oracle.ts --network goerli
export const queryGasPriceOracle = async () => {
  try {

    const gasPriceOracleAddress = '0xF883Bb6FbDcea8664e37F2f572f6659CE1AcE75A';

    const GasPriceOracle = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleInstance = GasPriceOracle.attach(gasPriceOracleAddress);

    const gasPrices = await gasPriceOracleInstance.getGasPrices(5);
    const sourceGasPrice = gasPrices[0];
    const relativeGasPrice = gasPrices[1];
    console.log(`sourceGasPrice are: ${sourceGasPrice.toString()}`);
    console.log(`relativeGasPrice are: ${relativeGasPrice.toString()}`);

  } catch (error) {
    console.log("Error in query Prices from GasPriceOracle", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  queryGasPriceOracle()
  .then(() => {
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });