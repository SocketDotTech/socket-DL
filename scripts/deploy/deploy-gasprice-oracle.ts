import hre from "hardhat";
import { ethers } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContractWithArgs, getAddresses, storeAddresses } from "./utils";
import { chainIds } from "../constants/networks";
import { transmitterAddress } from "../constants/config";

/**
 * Deploys gasprice oracle , set transmitManager to oracle followed by granting transmitter role to the transmitter
 */
// npx hardhat run scripts/deploy/deploy-gasprice-oracle.ts --network polygon-mumbai

export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner } = await getNamedAccounts();
    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);

    const network = hre.network.name;

    const gasPriceOracle: Contract = await deployContractWithArgs(
      "GasPriceOracle",
      [socketSigner.address, chainIds[network]],
      socketSigner,
      "contracts/GasPriceOracle.sol"
    );

    const addresses = await getAddresses(chainIds[network]);
    addresses["GasPriceOracle"] = gasPriceOracle.address;
    await storeAddresses(addresses, chainIds[network]);

    const transmitManagerAddress = addresses["TransmitManager"];

    const tx = await gasPriceOracle
      .connect(socketSigner)
      .setTransmitManager(transmitManagerAddress);
    console.log(`Setting transmit manager in oracle and resulting transactionHash is: ${tx.hash}`);
    await tx.wait();

    //grant transmitter role to transmitter-address
    const transmitter = transmitterAddress[network];

    const TransmitManager = await ethers.getContractFactory('TransmitManager');
    const transmitManagerInstance = TransmitManager.attach(transmitManagerAddress);
    const grantTransmitterRoleTxn = await transmitManagerInstance
      .connect(socketSigner)
      .grantTransmitterRole(chainIds[network], transmitter);

    console.log(`granted transmitter role to ${transmitter} and resulting transactionHash is: ${grantTransmitterRoleTxn.hash}`);
    await grantTransmitterRoleTxn.wait();
  }
  catch (error) {
    console.log("Error in setting up gas-price-oracle contract", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
