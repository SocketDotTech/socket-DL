import { constants } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { createObj, getInstance, storeAddresses } from "./utils";
import { ChainSocketAddresses, IntegrationTypes } from "../../src";

export default async function registerSwitchBoard(
  switchBoardAddress: string,
  remoteChainSlug: string,
  capacitorType: number,
  maxPacketLength: number,
  signer: SignerWithAddress,
  integrationType: string,
  config: ChainSocketAddresses
) {
  try {
    const socket = await getInstance("Socket", config["Socket"]);
    let capacitor = await socket.capacitors__(
      switchBoardAddress,
      remoteChainSlug
    );

    if (capacitor === constants.AddressZero) {
      const registerTx = await socket
        .connect(signer)
        .registerSwitchBoard(
          switchBoardAddress,
          maxPacketLength,
          remoteChainSlug,
          capacitorType
        );
      console.log(
        `Registering Switchboard ${switchBoardAddress}: ${registerTx.hash}`
      );
      await registerTx.wait();
    }

    // get capacitor and decapacitor for config
    capacitor = await socket.capacitors__(switchBoardAddress, remoteChainSlug);
    const decapacitor = await socket.decapacitors__(
      switchBoardAddress,
      remoteChainSlug
    );

    config = setCapacitorPair(config, remoteChainSlug, integrationType, {
      capacitor,
      decapacitor,
    });

    return config;
  } catch (error) {
    console.log("Error in registering switchboards", error);
    throw error;
  }
}

function setCapacitorPair(config, chainSlug, integrationType, contracts) {
  config = createObj(
    config,
    ["integrations", chainSlug, integrationType, "capacitor"],
    contracts["capacitor"]
  );

  config = createObj(
    config,
    ["integrations", chainSlug, integrationType, "decapacitor"],
    contracts["decapacitor"]
  );

  return config;
}
