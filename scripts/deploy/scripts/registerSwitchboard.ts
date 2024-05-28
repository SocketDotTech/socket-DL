import { Wallet, constants } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { createObj, getInstance } from "../utils";
import { ChainSlug, ChainSocketAddresses } from "../../../src";
import { initialPacketCount, overrides } from "../config";
import { handleOps, isKinto } from "../utils/kinto/kinto";

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

    let capacitor = await socket.capacitors__(
      switchBoardAddress,
      remoteChainSlug
    );

    if (capacitor === constants.AddressZero) {
      let registerTx;
      const txRequest =
        await switchboard.populateTransaction.registerSiblingSlug(
          remoteChainSlug,
          maxPacketLength,
          capacitorType,
          initialPacketCount,
          siblingSwitchBoardAddress,
          {
            ...overrides(await signer.getChainId()),
          }
        );

      if (isKinto(await signer.getChainId())) {
        registerTx = await handleOps(
          process.env.SOCKET_OWNER_ADDRESS,
          [txRequest],
          process.env.SOCKET_SIGNER_KEY
        );
      } else {
        registerTx = await (
          await switchboard.signer.sendTransaction(txRequest)
        ).wait();
      }

      console.log(
        `Registering Switchboard remoteChainSlug - ${remoteChainSlug} ${switchBoardAddress}: ${registerTx.transactionHash}`
      );
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
