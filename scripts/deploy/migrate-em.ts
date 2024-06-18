import { DeploymentAddresses } from "../../src";
import { configureRoles } from "./scripts/configureRoles";
import { deployForChains } from "./scripts/deploySocketFor";

const deploy = async () => {
    try {
        const chains = [];
        const addresses: DeploymentAddresses = await deployForChains(chains);
        await configureRoles(addresses, chains, true);
    } catch (error) {
        console.log("Error:", error);
    }
};

deploy();