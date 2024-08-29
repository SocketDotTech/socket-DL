import { SocketSigner } from "@socket.tech/dl-common";
import { Wallet } from "ethers";

import {
  ChainSlugToId,
  ChainSocketAddresses,
  CORE_CONTRACTS,
} from "../../../src";
import { getProviderFromChainSlug } from "../../constants";
import { getRelayAPIKEY, getRelayUrl } from "./utils";
import { mode } from "../config/config";

export const getSocketSigner = async (
  chainSlug: number,
  addresses: ChainSocketAddresses,
  useSafe: boolean = false,
  useEOA: boolean = true
): Promise<SocketSigner> => {
  const provider = getProviderFromChainSlug(chainSlug);
  const wallet: Wallet = new Wallet(
    process.env.SOCKET_SIGNER_KEY as string,
    provider
  );

  const safeAddress = addresses["SafeL2"] && useSafe ? addresses["SafeL2"] : "";
  const safeWrapperAddress =
    addresses["SafeL2"] && useSafe
      ? addresses[CORE_CONTRACTS.MultiSigWrapper]
      : "";

  return new SocketSigner(
    provider,
    ChainSlugToId[chainSlug],
    safeAddress,
    safeWrapperAddress,
    await getRelayUrl(mode),
    getRelayAPIKEY(mode),
    wallet,
    useSafe,
    useEOA
  );
};
