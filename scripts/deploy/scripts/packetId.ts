import { BigNumber } from "ethers";
import { hexZeroPad } from "ethers/lib/utils";

interface PackedDetails {
  chainSlug: number;
  accumAddr: string;
  packetNonce: string;
}

export const unpackPacketId = (packetId: BigNumber): PackedDetails => {
  const packetIdHex = packetId.toHexString();
  const slugLength = packetIdHex.length - 58;

  const chainSlug = parseInt(
    BigNumber.from(`0x${packetIdHex.substring(2, 2 + slugLength)}`).toString()
  );
  const accumAddr = `0x${packetIdHex.substring(
    2 + slugLength,
    40 + 2 + slugLength
  )}`;
  const packetNonce = BigNumber.from(
    `0x${packetIdHex.substring(40 + 2 + slugLength)}`
  ).toString();

  return {
    chainSlug,
    accumAddr,
    packetNonce,
  };
};

export const packPacketId = (
  chainSlug: number,
  accumAddr: string,
  packetNonce: string
): string => {
  const nonce = BigNumber.from(packetNonce).toHexString();
  const nonceHex =
    nonce.length <= 16 ? hexZeroPad(nonce, 8).substring(2) : nonce.substring(2);
  const id =
    BigNumber.from(chainSlug).toHexString() + accumAddr.substring(2) + nonceHex;

  return BigNumber.from(id).toString();
};
