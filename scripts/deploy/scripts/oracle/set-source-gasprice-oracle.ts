import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/set-source-gasprice-oracle.ts --network polygon-mumbai
export const setSourceGasPriceInOracle = async () => {
  try {
    const gasPriceOracleAddress = '0xe1C2aE858E8F64be00343aE052F9D3a08856BbB9';

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const GasPriceOracle = await ethers.getContractFactory('GasPriceOracle');
    const gasPriceOracleInstance = GasPriceOracle.attach(gasPriceOracleAddress);

    const tx = await gasPriceOracleInstance.connect(socketOwnerSigner).setSourceGasPrice(
      ethers.utils.parseUnits('350', 'gwei'),
      {
        gasLimit: 70000,
        gasPrice: ethers.utils.parseUnits("50", "gwei").toNumber()
      });
    await tx.wait();
  } catch (error) {
    console.log("Error in set-sourceGasPrice-In-Oracle", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  setSourceGasPriceInOracle()
  .then(() => {
    console.log("✅ finished running the set-sourceGasPrice-In-Oracle.");
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });