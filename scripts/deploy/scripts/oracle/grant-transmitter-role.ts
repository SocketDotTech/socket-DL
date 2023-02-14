import { BigNumber } from 'ethers';
import { ethers, run } from 'hardhat';
const hre = require("hardhat");

// usage: npx hardhat run scripts/deploy/scripts/oracle/grant-transmitter-role.ts --network goerli
export const grantTransmitterRole = async () => {
  try {

    const { socketOwner } = await getNamedAccounts();
    const socketOwnerSigner = await ethers.getSigner(socketOwner);
    console.log(`socketOwner is: ${socketOwner}`);

    const transmitManagerAddress = '0xD670A70781CB24F4525536cEa0cb7639635c9a87';
    const TransmitManager = await ethers.getContractFactory('TransmitManager');
    const transmitManagerInstance = TransmitManager.attach(transmitManagerAddress);

    const tx = await transmitManagerInstance.connect(socketOwnerSigner).grantTransmitterRole(
      137,
      socketOwner,
      {
        gasLimit: 50000,
        gasPrice: ethers.utils.parseUnits("50", "gwei").toNumber()
      });
    await tx.wait();
  } catch (error) {
    console.log("Error in grantTransmitterRole", error);
    return {
      success: false,
    };
  }
};

export const sleep = (delay: number) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

  grantTransmitterRole()
  .then(() => {
    console.log("✅ finished running the grantTransmitterRole.");
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });