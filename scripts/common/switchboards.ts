import { Contract, Wallet, utils } from "ethers";
import { StaticJsonRpcProvider } from "@ethersproject/providers";
import {
  IntegrationTypes,
  ChainSlug,
  getSwitchboardAddress,
  DeploymentMode,
} from "../../src";
import { getProviderFromChainSlug } from "../constants";
import FastSwitchboardABI from "@socket.tech/dl-core/artifacts/abi/FastSwitchboard.json";
import NativeSwitchboardABI from "@socket.tech/dl-core/artifacts/abi/NativeSwitchboardBase.json";
import { getRoleHash } from "../deploy/utils/utils";

const sbContracts: { [key: string]: Contract } = {};
export const getSwitchboardInstance = (
  chain: ChainSlug,
  siblingChain: ChainSlug,
  integrationType: IntegrationTypes,
  mode: DeploymentMode
): Contract | undefined => {
  let switchboardAddress: string;
  try {
    switchboardAddress = getSwitchboardAddress(
      chain,
      siblingChain,
      integrationType,
      mode
    );
  } catch (e) {
    // means no switchboard found for given params
    return;
  }
  if (!sbContracts[`${chain}${siblingChain}${switchboardAddress}`]) {
    const provider: StaticJsonRpcProvider = getProviderFromChainSlug(chain);

    if (!process.env.SOCKET_SIGNER_KEY)
      throw new Error("SOCKET_SIGNER_KEY not set");

    const signer: Wallet = new Wallet(process.env.SOCKET_SIGNER_KEY, provider);

    sbContracts[`${chain}${siblingChain}${switchboardAddress}`] = new Contract(
      switchboardAddress,
      integrationType == IntegrationTypes.native
        ? NativeSwitchboardABI
        : FastSwitchboardABI,
      signer
    );
  }
  return sbContracts[`${chain}${siblingChain}${switchboardAddress}`];
};

export const checkRole = async (
  role: string,
  instance: Contract,
  address: string = ""
): Promise<boolean> => {
  if (!address) address = await instance.signer.getAddress();
  return await instance.callStatic["hasRole(bytes32,address)"](
    getRoleHash(role),
    address
  );
};
