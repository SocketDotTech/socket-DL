import { BucketFinalityType } from "./socket-types";

/*
Transmission param format:
- first byte - version - current version is 1
- 2nd  byte - finalityType - specify if using buckets, block, or time. (1: bucket, 2: block, 3: time)
- next 4 bytes - value - bucket (1:fast, 2:medium, 3:slow), block (min block confirmations) or time (min time elapsed)

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
  type: BucketFinalityType,
  currentBlock: number,
  eventBlock: number,
  currentTime: number,
  eventTime: number,
  finalityBlockDiff: number,
  finalityTimeDiff: number
) => {
  if (type === BucketFinalityType.block) {
    if (!currentBlock || !eventBlock || !finalityBlockDiff) {
      console.log("Invalid data for block finality check");
      return false;
    }
    return currentBlock - eventBlock >= finalityBlockDiff;
  } else if (type === BucketFinalityType.time) {
    if (!currentTime || !eventTime || !finalityTimeDiff) {
      console.log("Invalid data for time finality check");
      return false;
    }
    return currentTime - eventTime >= finalityTimeDiff;
  } else {
    console.log("Invalid finality type");
    return false;
  }
};
