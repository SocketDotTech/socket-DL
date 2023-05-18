import { Wallet, constants } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { createObj, getInstance } from "../utils";
import { ChainSlug, ChainSocketAddresses } from "../../../src";
import { overrides } from "../config";

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
    const socket = (await getInstance("Socket", config["Socket"])).connect(
      signer
    );
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
          capacitorType,
          { ...overrides[await signer.getChainId()] }
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
