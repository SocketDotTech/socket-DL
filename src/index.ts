import { DeploymentMode } from "./types";

export * from "./types";
export * from "./addresses";

export const version = {
    [DeploymentMode.DEV]: "GARAM_MASALA",
    [DeploymentMode.SURGE]: "HING",
    [DeploymentMode.PROD]: "FINGERROOT",
};

  



