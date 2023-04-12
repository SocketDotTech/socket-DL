import * as deploymentAddresses from "../../deployments/addresses.json";

export const deployedAddresses = deploymentAddresses;
if (!deployedAddresses) {
  console.log("deployedAddresses not found");
  throw new Error("deployedAddresses not found");
}
