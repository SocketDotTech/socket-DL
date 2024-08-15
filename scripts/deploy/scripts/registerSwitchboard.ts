import { constants } from "ethers";
import { createObj, getInstance } from "../utils";
import { ChainSlug, ChainSocketAddresses } from "../../../src";
import { initialPacketCount, overrides } from "../config/config";
import { SocketSigner } from "@socket.tech/dl-common";

export default async function registerSwitchboardForSibling(
  switchBoardAddress: string,
  siblingSwitchBoardAddress: string,
  remoteChainSlug: string | ChainSlug,
  capacitorType: number,
  maxPacketLength: number,
  signer: SocketSigner,
  integrationType: string,
  config: ChainSocketAddresses
) {
  try {
    const socket = (await getInstance("Socket", config["Socket"])).connect(
      signer
    );

    // used fast switchboard here as all have same function signature
    const switchboard = (
      await getInstance("FastSwitchboard", switchBoardAddress)
    ).connect(signer);

    let capacitor = await socket.capacitors__(
      switchBoardAddress,
      remoteChainSlug
    );

    if (capacitor === constants.AddressZero) {
      const registerTx = await switchboard.registerSiblingSlug(
        remoteChainSlug,
        maxPacketLength,
        capacitorType,
        initialPacketCount,
        siblingSwitchBoardAddress,
        {
          ...overrides(await signer.getChainId()),
        }
      );
      console.log(
        `Registering Switchboard remoteChainSlug - ${remoteChainSlug} ${switchBoardAddress}: ${registerTx.hash}`
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
