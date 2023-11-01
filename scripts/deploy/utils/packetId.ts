import { BigNumber } from "ethers";
import { hexZeroPad } from "ethers/lib/utils";

interface PackedDetails {
  chainSlug: number;
  capacitorAddr: string;
  packetNonce: string;
}

export const unpackPacketId = (packetId: BigNumber): PackedDetails => {
  const packetIdHex = packetId.toHexString();
  const slugLength = packetIdHex.length - 58;

  const chainSlug = parseInt(
    BigNumber.from(`0x${packetIdHex.substring(2, 2 + slugLength)}`).toString()
  );
  const capacitorAddr = `0x${packetIdHex.substring(
    2 + slugLength,
    40 + 2 + slugLength
  )}`;
  const packetNonce = BigNumber.from(
    `0x${packetIdHex.substring(40 + 2 + slugLength)}`
  ).toString();

  return {
    chainSlug,
    capacitorAddr,
    packetNonce,
  };
};

export const packPacketId = (
  chainSlug: number,
  capacitorAddr: string,
  packetNonce: string
): string => {
  const nonce = BigNumber.from(packetNonce).toHexString();
  const nonceHex =
    nonce.length <= 16 ? hexZeroPad(nonce, 8).substring(2) : nonce.substring(2);
  const id =
    BigNumber.from(chainSlug).toHexString() +
    capacitorAddr.substring(2) +
    nonceHex;

  return BigNumber.from(id).toString();
};

export function encodePacketId(
  chainSlug: number,
  capacitorAddress: string,
  packetCount: number
) {
  const encodedValue =
    (BigInt(chainSlug) << BigInt(224)) |
    (BigInt(capacitorAddress) << BigInt(64)) |
    BigInt(packetCount);

  // Ensure the result is a 32-byte hex string (bytes32 in Solidity)
  const resultHex = encodedValue.toString(16).padStart(64, "0");
  return "0x" + resultHex;
}
