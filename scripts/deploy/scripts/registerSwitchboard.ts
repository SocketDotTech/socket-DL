import { Wallet, constants } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { createObj, getInstance } from "../utils";
import { ChainSlug, ChainSocketAddresses } from "../../../src";
import { initialPacketCount, overrides, socketOwner } from "../config/config";

export default async function registerSwitchboardForSibling(
  switchBoardAddress: string,
  siblingSwitchBoardAddress: string,
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

    // used fast switchboard here as all have same function signature
    const switchboard = (
      await getInstance("FastSwitchboard", switchBoardAddress)
    ).connect(signer);

    // send overrides while reading capacitor to avoid errors on mantle chain
    // some chains give balance error if gas price is used with from address as zero
    // therefore override from address as well
    let capacitor = await socket.capacitors__(
      switchBoardAddress,
      remoteChainSlug,
      { ...(await overrides(await signer.getChainId())), from: socketOwner }
    );

    if (capacitor === constants.AddressZero) {
      const registerTx = await switchboard.registerSiblingSlug(
        remoteChainSlug,
        maxPacketLength,
        capacitorType,
        initialPacketCount,
        siblingSwitchBoardAddress,
        {
          ...(await overrides(await signer.getChainId())),
        }
      );
      console.log(
        `Registering Switchboard remoteChainSlug - ${remoteChainSlug} ${switchBoardAddress}: ${registerTx.hash}`
      );

      await registerTx.wait();
    }

    // get capacitor and decapacitor for config
    // send overrides while reading capacitor/decapacitor to avoid errors on mantle chain
    // some chains give balance error if gas price is used with from address as zero
    // therefore override from address as well
    capacitor = await socket.capacitors__(switchBoardAddress, remoteChainSlug, {
      ...(await overrides(await signer.getChainId())),
      from: socketOwner,
    });
    const decapacitor = await socket.decapacitors__(
      switchBoardAddress,
      remoteChainSlug,
      { ...(await overrides(await signer.getChainId())), from: socketOwner }
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
