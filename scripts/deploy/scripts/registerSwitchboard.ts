import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { createObj } from "../utils";
import { IntegrationTypes } from "../../../src";

export default async function registerSwitchBoard(
  socket: Contract,
  switchBoardAddress: string,
  remoteChainSlug: string,
  capacitorType: number,
  signer: SignerWithAddress,
  integrationType: IntegrationTypes,
  config: object
): Promise<object> {
  try {
    const registerTx = await socket.connect(signer).registerSwitchBoard(
      switchBoardAddress,
      remoteChainSlug,
      capacitorType
    );
    console.log(`Registering Switchboard ${switchBoardAddress}: ${registerTx.hash}`);
    await registerTx.wait();

    // get capacitor and decapacitor for config
    const capacitor = await socket._capacitors__(switchBoardAddress, remoteChainSlug);
    const decapacitor = await socket._decapacitors__(switchBoardAddress, remoteChainSlug);

    config = setCapacitorPair(
      config,
      remoteChainSlug,
      integrationType,
      { capacitor, decapacitor }
    )

    return
  } catch (error) {
    console.log("Error in registering switchboards", error);
    throw error;
  }
};


function setCapacitorPair(
  config,
  chainSlug,
  integrationType,
  contracts
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

  return config;
}
