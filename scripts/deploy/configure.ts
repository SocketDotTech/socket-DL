import fs from "fs";
import hre, { getNamedAccounts, ethers } from "hardhat";
import { constants, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  chainIds,
  attesterAddress,
  timeout,
  fastIntegration,
  slowIntegration,
  contractNames,
  nativeBridgeIntegration
} from "../constants";
import {
  getInstance,
  deployedAddressPath,
  storeAddresses,
  createObj,
  getChainId,
  getNotaryAddress,
  getVerifierAddress
} from "./utils";
import { deployNotary, deployAccumulator, deployVerifier } from "./contracts";
import { ChainSocketAddresses } from "./types";

const localChain: keyof typeof chainIds = "hardhat";
const remoteChain: keyof typeof chainIds = "hardhat";
const config = [fastIntegration, slowIntegration];
const configForCounter = fastIntegration;

if (!localChain) throw new Error("Provide local chain id");
if (!remoteChain) throw new Error("Provide remote chain id");
// if (localChain === remoteChain) throw new Error("Wrong chains");

if (!fs.existsSync(deployedAddressPath)) {
  throw new Error("addresses.json not found");
}
if (config.length === 0 && configForCounter === "")
  throw new Error("No configuration provided");

const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));
if (!addresses[chainIds[localChain]] || !addresses[chainIds[remoteChain]]) {
  throw new Error("Deployed Addresses not found");
}

const remoteConfig: ChainSocketAddresses = addresses[chainIds[remoteChain]];
let localConfig: ChainSocketAddresses = addresses[chainIds[localChain]];

const getSigners = async () => {
  const { socketOwner, counterOwner } = await getNamedAccounts();
  const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
  const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);
  return { socketSigner, counterSigner };
};

const remoteNotary = (notaryName: string) => {
  let remoteNotary = getNotaryAddress(
    notaryName,
    chainIds[localChain],
    remoteConfig
  );

  if (!remoteNotary) return constants.AddressZero;
  return remoteNotary;
};

const deployLocalNotary = async (integrationType, notaryName, socketSigner) => {
  try {
    let notary;
    const address = getNotaryAddress(
      notaryName,
      chainIds[remoteChain],
      localConfig
    );

    if (!address) {
      notary = await deployNotary(
        notaryName,
        localChain,
        localConfig["SignatureVerifier"],
        remoteNotary(notaryName),
        socketSigner
      );
      const grantAttesterRoleTx = await notary
        .connect(socketSigner)
        .grantAttesterRole(chainIds[remoteChain], attesterAddress[localChain]);
      await grantAttesterRoleTx.wait();

      if (notaryName === "AdminNotary") {
        localConfig[notaryName] = notary.address;
      }

      localConfig = createObj(
        localConfig,
        ["integrations", chainIds[remoteChain], integrationType, "notary"],
        notary.address
      );
    } else {
      notary = await getInstance(notaryName, address);
      if (!config["integrations"]?.[chainIds[remoteChain]]?.[integrationType]?.["notary"])
        localConfig = createObj(
          localConfig,
          ["integrations", chainIds[remoteChain], integrationType, "notary"],
          notary.address
        );
    }
    return notary;
  } catch (error) {
    throw new Error(
      `Error while deploying notary contract: ${notaryName}: ${error}`
    );
  }
};

const deployLocalAccum = async (
  configurationType,
  notaryAddress,
  socketSigner
) => {
  try {
    let accum;
    if (!localConfig["integrations"]?.[chainIds[remoteChain]]?.[configurationType]?.["accum"]) {
      accum = await deployAccumulator(
        localConfig["Socket"],
        notaryAddress,
        remoteChain,
        socketSigner
      );

      localConfig = createObj(
        localConfig,
        ["integrations", chainIds[remoteChain], configurationType, "accum"],
        accum.address
      );

    } else {
      accum = await getInstance(
        "SingleAccum",
        localConfig["integrations"]?.[chainIds[remoteChain]]?.[configurationType]?.["accum"]
      );
    }

    return accum;
  } catch (error) {
    throw new Error(
      `Error while deploying accum contract: ${error}`
    );
  }
};

const deployLocalVerifier = async (
  integrationType,
  verifierName,
  notaryAddress,
  socketSigner
) => {
  try {
    let verifier;
    const address = getVerifierAddress(
      verifierName,
      chainIds[remoteChain],
      localConfig
    );

    if (!address) {
      verifier = await deployVerifier(
        verifierName,
        timeout[localChain],
        notaryAddress,
        socketSigner
      );

      if (verifierName === "Verifier") {
        localConfig[verifierName] = verifier.address;
      }

      localConfig = createObj(
        localConfig,
        ["integrations", chainIds[remoteChain], integrationType, "verifier"],
        verifier.address
      );
    } else {
      verifier = await getInstance(verifierName, address);
      if (!config["integrations"]?.[chainIds[remoteChain]]?.[integrationType]?.["verifier"])
        localConfig = createObj(
          localConfig,
          ["integrations", chainIds[remoteChain], integrationType, "verifier"],
          verifier.address
        );
    }

    return verifier;
  } catch (error) {
    throw new Error(
      `Error while deploying accum contract: ${verifierName}: ${error}`
    );
  }
};

const setupContracts = async (
  localNotary,
  localNotaryName,
  socketSigner
) => {
  // check if remote notary and accum exists
  const { notary, integrationType } = contractNames(
    "",
    remoteChain,
    localChain
  );

  const remoteNotaryAddress = getNotaryAddress(
    notary,
    chainIds[localChain],
    remoteConfig
  );

  if (!remoteNotaryAddress) return;
  const remoteNotary: Contract = await getInstance(notary, remoteNotaryAddress);

  await hre.changeNetwork(remoteChain);
  const signers = await getSigners();
  let updateRemoteNotaryTx = await remoteNotary
    .connect(signers.socketSigner)
    .updateRemoteNotary(localNotary.address);
  await updateRemoteNotaryTx.wait();

  // set fxchild for l2 to l1 comm
  if (notary === "PolygonL1Notary") {
    const setFxChildTunnelTx = await remoteNotary
      .connect(signers.socketSigner)
      .setFxChildTunnel(localNotary.address);
    await setFxChildTunnelTx.wait();
  }

  await hre.changeNetwork(localChain);
  updateRemoteNotaryTx = await localNotary
    .connect(socketSigner)
    .updateRemoteNotary(remoteNotary.address);
  await updateRemoteNotaryTx.wait();

  // set fxchild for l2 to l1 comm
  if (localNotaryName === "PolygonL1Notary") {
    const setFxChildTunnelTx = await localNotary
      .connect(socketSigner)
      .setFxChildTunnel(remoteNotary.address);
    await setFxChildTunnelTx.wait();
  }
};

/**
 * Used to deploy config related contracts like Accum, deaccum, verifier and notary.
 * It checks the deployed addresses, and if a contract exists, it will use the deployed instance
 * @param configurationType type of configurations
 * @param socketSigner
 */
const setupConfig = async (
  configurationType: string,
  socketSigner: SignerWithAddress
) => {
  const contracts = contractNames(configurationType, localChain, remoteChain);
  if (configurationType !== contracts.integrationType)
    throw new Error("Given Configuration not supported");

  console.log(
    `Deploying contracts: SingleAccum, ${contracts.notary}, ${contracts.verifier} for ${contracts.integrationType} integration type`
  );

  let notary: Contract = await deployLocalNotary(
    configurationType,
    contracts.notary,
    socketSigner
  );
  let verifier = await deployLocalVerifier(
    configurationType,
    contracts.verifier,
    notary.address,
    socketSigner
  );
  let accum = await deployLocalAccum(
    configurationType,
    notary.address,
    socketSigner
  );

  // optional notary and accum settings
  if (
    configurationType !== fastIntegration &&
    configurationType !== slowIntegration
  )
    await setupContracts(notary, contracts.notary, socketSigner);

  // add config to socket
  const socket: Contract = await getInstance("Socket", localConfig["Socket"]);
  const addConfigTx = await socket
    .connect(socketSigner)
    .addConfig(
      chainIds[remoteChain],
      accum.address,
      localConfig["SingleDeaccum"],
      verifier.address,
      configurationType
    );
  await addConfigTx.wait();
};

export const main = async () => {
  try {
    const chainId = await getChainId();
    if (chainId !== chainIds[localChain])
      throw new Error("Wrong network connected");

    const { socketSigner, counterSigner } = await getSigners();

    // deploy contracts for different configurations
    for (let index = 0; index < config.length; index++) {
      await setupConfig(config[index], socketSigner);
    }

    await storeAddresses(localConfig, chainIds[localChain]);

    // add a config to plugs on local and remote
    const counter: Contract = await getInstance(
      "Counter",
      localConfig["Counter"]
    );
    const tx = await counter
      .connect(counterSigner)
      .setSocketConfig(
        chainIds[remoteChain],
        remoteConfig["Counter"],
        configForCounter
      );
    await tx.wait();
    console.log(
      `Set config ${configForCounter} for ${chainIds[remoteChain]} chain id!`
    );
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
