import { DeploymentMode } from "./types";

export * from "./types";
export * from "./addresses";

export const version = {
  [DeploymentMode.DEV]: "IMLI",
  [DeploymentMode.SURGE]: "IMLI",
  [DeploymentMode.PROD]: "FINGERROOT",
};
