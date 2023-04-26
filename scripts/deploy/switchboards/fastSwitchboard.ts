import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { timeout } from "../../constants";
import { chainKeyToSlug } from "../../../src";
import { watcherAddresses } from "../config";

export const fastSwitchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "FastSwitchboard",
    args: [
      signerAddress,
      socketAddress,
      oracleAddress,
      chainKeyToSlug[network],
      timeout[network],
    ],
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
    const watcherRoleSet = await switchboard["hasRole(string,uint256,address)"](
      "WATCHER_ROLE",
      remoteChainSlug,
      watcherAddresses[localChain]
    );

    // role setup
    if (!watcherRoleSet) {
      const grantWatcherRoleTx = await switchboard
        .connect(signer)
        .grantWatcherRole(remoteChainSlug, watcherAddresses[localChain]);
      console.log(`grantWatcherRoleTx: ${grantWatcherRoleTx.hash}`);
      await grantWatcherRoleTx.wait();
    }
  } catch (error) {
    console.log("Error in setting up fast switchboard", error);
  }
};
