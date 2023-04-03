import { Contract, utils } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { chainSlugs, timeout, watcherAddress } from "../../constants";
import { getRoleHash } from "../utils";
import { createDigest, createSignature } from "../utils/signature";

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
  return {
    contractName: "FastSwitchboard",
    args: [signerAddress, oracleAddress, chainSlugs[network], timeout[network]],
    path: "contracts/switchboard/default-switchboards/FastSwitchboard.sol",
  };
};

export const setupFast = async (
  switchboard: Contract,
  remoteChainSlug: number,
  localChain: string,
  remoteChain: string,
  signer: SignerWithAddress
) => {
  try {
    const executionOverheadOnChain = await switchboard.executionOverhead(
      remoteChainSlug
    );
    const attestGasLimitOnChain = await switchboard.attestGasLimit(
      remoteChainSlug
    );
    const watcherRoleSet = await switchboard["hasRole(string,uint256,address)"](
      "WATCHER_ROLE",
      remoteChainSlug,
      watcherAddress[localChain]
    );

    // role setup
    if (!watcherRoleSet) {
      const grantWatcherRoleTx = await switchboard
        .connect(signer)
        .grantWatcherRole(remoteChainSlug, watcherAddress[localChain]);
      console.log(`grantWatcherRoleTx: ${grantWatcherRoleTx.hash}`);
      await grantWatcherRoleTx.wait();
    }

    // fees setup
    let nonce = await switchboard.nextNonce(signer.address);

    if (parseInt(executionOverheadOnChain) !== executionOverhead[remoteChain]) {
      const digest = createDigest(
        "EXECUTION_OVERHEAD_UPDATE",
        nonce,
        chainSlugs[localChain],
        remoteChainSlug,
        executionOverhead[remoteChain]
      );
      const signature = createSignature(digest, signer);
      const setExecutionOverheadTx = await switchboard
        .connect(signer)
        .setExecutionOverhead(
          nonce++,
          remoteChainSlug,
          executionOverhead[remoteChain],
          signature
        );
      console.log(`setExecutionOverheadTx: ${setExecutionOverheadTx.hash}`);
      await setExecutionOverheadTx.wait();
    }

    if (parseInt(attestGasLimitOnChain) !== attestGasLimit[remoteChain]) {
      const digest = createDigest(
        "ATTEST_GAS_LIMIT_UPDATE",
        chainSlugs[localChain],
        remoteChainSlug,
        nonce,
        attestGasLimit[remoteChain]
      );
      const signature = createSignature(digest, signer);
      const setAttestGasLimitTx = await switchboard
        .connect(signer)
        .setAttestGasLimit(
          nonce++,
          remoteChainSlug,
          attestGasLimit[remoteChain],
          signature
        );
      console.log(`setAttestGasLimitTx: ${setAttestGasLimitTx.hash}`);
      await setAttestGasLimitTx.wait();
    }
  } catch (error) {
    console.log("Error in setting up fast switchboard", error);
  }
};
