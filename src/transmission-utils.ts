/*
Transmission param format:
- first byte - version - current version is 1
- 2nd  byte - finalityType (1: bucket)
- next 4 bytes - value - bucket (1:fast, 2:medium, 3:slow)

eg : want to transmit message with slow speed - 
transmissionParam = 0x0101000000030000000000000000000000000000000000000000000000000000

eg : want to transmit message with fast speed -
transmissionParam = 0x0101000000010000000000000000000000000000000000000000000000000000

if version is 0, or invalid finality type, or invalid value is mentioned, it will use the default Bucket for that chain
*/

export const decodeTransmissionParams = (transmissionParam: string) => {
  if (transmissionParam.length !== 64 && transmissionParam.length !== 66) {
    throw new Error("Invalid transmission param length");
  }
  transmissionParam = transmissionParam.replace("0x", "");
  const version = parseInt("0x" + transmissionParam.slice(0, 2));
  const finalityType = parseInt("0x" + transmissionParam.slice(2, 4));
  const value = parseInt("0x" + transmissionParam.slice(4, 12));

  return { version, finalityType, value };
};

export const encodeTransmissionParams = (
  version: number,
  finalityType: number,
  value: number
) => {
  let transmissionParam = "0x";
  transmissionParam += version.toString(16).padStart(2, "0");
  transmissionParam += finalityType.toString(16).padStart(2, "0");
  transmissionParam += value.toString(16).padStart(8, "0");
  transmissionParam = transmissionParam.padEnd(66, "0");
  return transmissionParam;
};

export const isTxFinalized = (
  currentBlock: number,
  eventBlock: number,
  finalityBlockDiff: number
) => {
  if (
    currentBlock == null ||
    currentBlock == undefined ||
    eventBlock == null ||
    eventBlock == undefined ||
    finalityBlockDiff == null ||
    finalityBlockDiff == undefined
  ) {
    throw new Error("Invalid data for block finality check");
  }
  return currentBlock - eventBlock >= finalityBlockDiff;
};
