import { BigNumber, Contract, ethers, utils } from "ethers";

import { packPacketId } from "@socket.tech/dl-common";

import capacitorAbiInterface from "@socket.tech/dl-core/artifacts/abi/SingleCapacitor.json";
import SocketSimulatorABI from "@socket.tech/dl-core/artifacts/abi/SocketSimulator.json";
import SwitchboardSimulatorABI from "@socket.tech/dl-core/artifacts/abi/SwitchboardSimulator.json";
import { getProviderFromChainSlug } from "../../constants";
import { version, ChainSlug } from "../../../src";
import { hexZeroPad } from "@ethersproject/bytes";

export const simulatorAbiInterface = new ethers.utils.Interface(
  SocketSimulatorABI
);
export const switchboardSimulatorAbiInterface = new ethers.utils.Interface(
  SwitchboardSimulatorABI
);
export const VERSION_HASH = utils.keccak256(
  utils.defaultAbiCoder.encode(["string"], [version])
);

export interface PacketInfo {
  root: string;
  packetId: string;
  capacitor: string;
}

export async function getPacketInfo(
  srcChainSlug: ChainSlug,
  capacitorAddress: string
): Promise<PacketInfo> {
  const capacitorContract = new Contract(
    capacitorAddress,
    capacitorAbiInterface,
    getProviderFromChainSlug(srcChainSlug)
  );
  const packetDetails = await capacitorContract.getNextPacketToBeSealed();
  const packetId = packPacketId(
    srcChainSlug,
    capacitorAddress,
    packetDetails[1].toString()
  );
  return {
    root: packetDetails[0],
    packetId,
    capacitor: capacitorAddress,
  };
}

export const packMessageId = (
  chainSlug: number,
  plugAddr: string,
  msgCount: string
): string => {
  const nonce = BigNumber.from(msgCount).toHexString();
  const nonceHex =
    nonce.length <= 16 ? hexZeroPad(nonce, 8).substring(2) : nonce.substring(2);

  const slug = BigNumber.from(chainSlug).toHexString();
  const slugHex = slug.length <= 10 ? hexZeroPad(slug, 4) : slug;
  const id = slugHex + plugAddr.substring(2) + nonceHex;
  return id.toLowerCase();
};
