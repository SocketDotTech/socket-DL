import { FinalityType } from "./socket-types";

export const decodeTransmissionParams = (transmissionParam: string) => {
  if (transmissionParam.length !== 64 && transmissionParam.length !== 66) {
    throw new Error("Invalid transmission param length");
  }
  transmissionParam = transmissionParam.replace("0x", "");
  const version = parseInt("0x" + transmissionParam.slice(0, 2)); // version 1
  const finalityType = parseInt("0x" + transmissionParam.slice(2, 4)); // bucket, block, time
  const value = parseInt("0x" + transmissionParam.slice(4, 12)); // bucket (see FinalityBucket enum), block (block number), time value in seconds

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

export const isTxFinalized = (data: {
  type: FinalityType;
  currentBlock: number;
  eventBlock: number;
  currentTime: number;
  eventTime: number;
  finalityBlockDiff: number;
  finalityTimeDiff: number;
}) => {
  if (data.type === FinalityType.block) {
    const { currentBlock, eventBlock, finalityBlockDiff } = data;
    if (!currentBlock || !eventBlock || !finalityBlockDiff) {
      console.log("Invalid data for block finality check");
      return false;
    }
    return currentBlock - eventBlock >= finalityBlockDiff;
  } else if (data.type === FinalityType.time) {
    if (!data.currentTime || !data.eventTime || !data.finalityTimeDiff) {
      console.log("Invalid data for time finality check");
      return false;
    }
    return data.currentTime - data.eventTime >= data.finalityTimeDiff;
  } else {
    console.log("Invalid finality type");
    return false;
  }
};
