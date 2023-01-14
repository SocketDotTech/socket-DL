import { Contract, utils } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { timeout, watcherAddress } from "../../constants";

const executionOverhead: {
  [key: string]: number;
} = {
  "bsc-testnet": 300000,
  "polygon-mainnet": 300000,
  bsc: 300000,
  "polygon-mumbai": 300000,
  "arbitrum-goerli": 300000,
  "optimism-goerli": 300000,
  goerli: 300000,
  hardhat: 300000,
  arbitrum: 300000,
  optimism: 300000,
  mainnet: 300000,
};

const attestGasLimit: {
  [key: string]: number;
} = {
  "bsc-testnet": 300000,
  "polygon-mainnet": 300000,
  bsc: 300000,
  "polygon-mumbai": 300000,
  "arbitrum-goerli": 300000,
  "optimism-goerli": 300000,
  goerli: 300000,
  hardhat: 300000,
  arbitrum: 300000,
  optimism: 300000,
  mainnet: 300000,
};

export const fastSwitchboard = (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return { contractName: "FastSwitchboard", args: [signerAddress, oracleAddress, timeout[network]], path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol" }
};

export const setupFast = async (
  switchboard: Contract,
  remoteChainSlug: number,
  remoteChain: string,
  signer: SignerWithAddress
) => {
  try {
    const executionOverheadOnChain = await switchboard.executionOverhead(remoteChainSlug)
    const attestGasLimitOnChain = await switchboard.attestGasLimit(remoteChainSlug);
    const watcherRoleSet = await switchboard.hasRole(
      utils.hexZeroPad(utils.hexlify(remoteChainSlug), 32),
      watcherAddress[remoteChain]
    );

    if (parseInt(executionOverheadOnChain) !== executionOverhead[remoteChain]) {
      const setExecutionOverheadTx = await switchboard.connect(signer).setExecutionOverhead(
        remoteChainSlug,
        executionOverhead[remoteChain]
      );
      console.log(`setExecutionOverheadTx: ${setExecutionOverheadTx.hash}`);
      await setExecutionOverheadTx.wait();
    }

    if (!watcherRoleSet) {
      const grantWatcherRoleTx = await switchboard.connect(signer).grantWatcherRole(
        remoteChainSlug,
        watcherAddress[remoteChain]
      );
      console.log(`grantWatcherRoleTx: ${grantWatcherRoleTx.hash}`);
      await grantWatcherRoleTx.wait();
    }

    if (parseInt(attestGasLimitOnChain) !== attestGasLimit[remoteChain]) {
      const setAttestGasLimitTx = await switchboard.connect(signer).setAttestGasLimit(
        remoteChainSlug,
        attestGasLimit[remoteChain]
      );
      console.log(`setAttestGasLimitTx: ${setAttestGasLimitTx.hash}`);
      await setAttestGasLimitTx.wait();
    }

  } catch (error) {
    console.log("Error in setting up fast switchboard", error);
  }
}