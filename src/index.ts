import { DeploymentMode } from "./socket-types";
export { getFinality } from "../scripts/rpcConfig/constants/finality";
export { getDefaultFinalityBucket } from "../scripts/rpcConfig/constants/defaultFinalityBucket";
export { getReSyncInterval } from "../scripts/rpcConfig/constants/reSyncInterval";
export { getOverrides } from "../scripts/constants/overrides";

export * from "./socket-types";
export * from "./enums";
export * from "./addresses";
export * from "./currency-util";
export * from "./transmission-utils";

export const version = {
  [DeploymentMode.DEV]: "IMLI",
  [DeploymentMode.SURGE]: "IMLI",
  [DeploymentMode.PROD]: "IMLI",
};
