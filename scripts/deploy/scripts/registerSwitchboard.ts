import { Wallet, constants } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { createObj, getInstance } from "../utils";
import { ChainSlug, ChainSocketAddresses } from "../../../src";

export default async function registerSwitchBoard(
  switchBoardAddress: string,
  remoteChainSlug: string | ChainSlug,
  capacitorType: number,
  maxPacketLength: number,
  signer: Wallet | SignerWithAddress,
  integrationType: string,
  config: ChainSocketAddresses
) {
  try {
    const socket = await getInstance("Socket", config["Socket"]);
    let capacitor = await socket.capacitors__(
      switchBoardAddress,
      remoteChainSlug
    );

    console.log(
      switchBoardAddress,
      maxPacketLength,
      remoteChainSlug,
      capacitorType,
      "register sb"
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
    console.log(switchBoardAddress, remoteChainSlug, "get sb");
    capacitor = await socket.capacitors__(switchBoardAddress, remoteChainSlug);
    const decapacitor = await socket.decapacitors__(
      switchBoardAddress,
      remoteChainSlug
    );

    config = setCapacitorPair(
      config,
      remoteChainSlug,
      integrationType,
      {
        capacitor,
        decapacitor,
      },
      switchBoardAddress
    );
  } catch (error) {
    console.log("Error in registering switchboards", error);
  }
  return config;
}

function setCapacitorPair(
  config,
  chainSlug,
  integrationType,
  contracts,
  switchboard
) {
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

  config = createObj(
    config,
    ["integrations", chainSlug, integrationType, "switchboard"],
    switchboard
  );

  return config;
}
