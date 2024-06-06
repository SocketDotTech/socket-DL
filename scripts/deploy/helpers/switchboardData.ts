import {
  CapacitorType,
  ChainSlug,
  DeploymentAddresses,
  IntegrationTypes,
  getAllAddresses,
} from "../../../src";
import { toLowerCase } from "../utils";

import { mode } from "../config/config";
import path from "path";
import fs from "fs";

type Switchboard = {
  switchboardId: string;
  srcChainSlug: number;
  dstChainSlug: number;
  maxPacketLength: number;
  integrationType: IntegrationTypes;
  srcSwitchboard?: string;
  dstSwitchboard?: string;
  srcCapacitor?: string;
  srcDecapacitor?: string;
  capacitorType: CapacitorType;
  isNativeSwitchboard: boolean;
  isEnabled: boolean;
};

export const getSwitchboardData = async () => {
  let addresses: DeploymentAddresses;
  try {
    addresses = getAllAddresses(mode);
  } catch (error) {
    console.log("couldn't fetch addresses: ", error);
    process.exit(0);
  }

  let switchboards: Switchboard[] = [];

  for (let chainSlug in addresses) {
    let chainAddresses = addresses[Number(chainSlug) as ChainSlug];
    if (!chainAddresses) {
      console.log("chain addresses not found chainSlug: ", chainSlug);
      return;
    }
    let integrations = chainAddresses["integrations"];
    if (!integrations) {
      console.log("integrations not found  chainSlug: ", chainSlug);
      return;
    }

    for (let siblingChainSlug in integrations) {
      let siblingIntegrations =
        integrations[Number(siblingChainSlug) as ChainSlug];
      if (!siblingIntegrations) {
        console.log(
          "sibling integrations not found chainSlug: ",
          chainSlug,
          siblingChainSlug
        );
        return;
      }

      let integrationTypes = Object.keys(siblingIntegrations);
      for (let integrationType of integrationTypes) {
        let switchboardAddresses =
          siblingIntegrations[integrationType as IntegrationTypes];

        let switchboard: Switchboard = {
          switchboardId: `${chainSlug}-${siblingChainSlug}-${toLowerCase(
            switchboardAddresses?.switchboard
          )}`,
          srcChainSlug: Number(chainSlug) as ChainSlug,
          dstChainSlug: Number(siblingChainSlug) as ChainSlug,
          maxPacketLength: 1,
          integrationType: integrationType as IntegrationTypes,
          srcCapacitor: toLowerCase(switchboardAddresses?.capacitor),
          srcDecapacitor: toLowerCase(switchboardAddresses?.decapacitor),
          srcSwitchboard: toLowerCase(switchboardAddresses?.switchboard),
          capacitorType: CapacitorType.singleCapacitor,
          isEnabled: true,
          dstSwitchboard: toLowerCase(
            addresses[siblingChainSlug].integrations[chainSlug][
              integrationType as IntegrationTypes
            ].switchboard
          ),
          isNativeSwitchboard: integrationType === IntegrationTypes.native,
        };
        switchboards.push(switchboard);
      }
    }
  }
  switchboards.forEach((s) =>
    console.log(
      s.switchboardId,
      s.dstSwitchboard,
      s.integrationType,
      s.isNativeSwitchboard
    )
  );
  console.log("total switchboards: ", switchboards.length);
  fs.writeFileSync(
    `./${mode}_switchboards.json`,
    JSON.stringify(switchboards, null, 2)
  );
};

getSwitchboardData();
