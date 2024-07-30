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
  addresses: ChainSocketAddresses
): Promise<SocketSigner> => {
  const provider = getProviderFromChainSlug(chainSlug);
  const wallet: Wallet = new Wallet(
    process.env.SOCKET_SIGNER_KEY as string,
    provider
  );

  if (addresses["Safe"]) {
    const safeAddress = addresses["Safe"];
    const safeWrapperAddress = addresses[CORE_CONTRACTS.MultiSigWrapper];

    return new SocketSigner(
      provider,
      ChainSlugToId[chainSlug],
      safeAddress,
      safeWrapperAddress,
      await getRelayUrl(mode),
      getRelayAPIKEY(mode),
      wallet,
      true,
      false
    );
  } else
    return new SocketSigner(
      provider,
      ChainSlugToId[chainSlug],
      "",
      "",
      "",
      "",
      wallet,
      false,
      true
    );
};
