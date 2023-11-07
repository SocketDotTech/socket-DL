import { DeploymentMode } from "./socket-types";

export * from "./socket-types";
export * from "./chain-types";
export * from "./addresses";

export const version = {
  [DeploymentMode.DEV]: "IMLI",
  [DeploymentMode.SURGE]: "IMLI",
  [DeploymentMode.PROD]: "IMLI",
};
