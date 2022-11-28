import fs from "fs";
import hre from "hardhat";

import { constants, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  chainIds,
  attesterAddress,
  timeout,
  fastIntegration,
  slowIntegration,
  contractNames,
} from "../../constants";
import {
  getInstance,
  createObj,
  getNotaryAddress,
  getVerifierAddress,
  storeAddresses,
  deployedAddressPath,
  getSigners
} from "./";
import { deployNotary, deployAccumulator, deployVerifier } from "../contracts";

let localChain, remoteChain, localConfig, remoteConfig;

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

const deployLocalNotary = async (integrationType, notaryName, socketSigner) => {
  try {
    let notary;
    const address = getNotaryAddress(
      notaryName,
      chainIds[remoteChain],
      localConfig
    );

    if (!address) {
      let remoteNotary = getNotaryAddress(notaryName, chainIds[localChain], remoteConfig)
      if(!remoteNotary) remoteNotary = constants.AddressZero;

      notary = await deployNotary(
        notaryName,
        localChain,
        localConfig["SignatureVerifier"],
        remoteNotary,
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
      if (!localConfig["integrations"]?.[chainIds[remoteChain]]?.[integrationType]?.["notary"])
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
      if (!localConfig["integrations"]?.[chainIds[remoteChain]]?.[integrationType]?.["verifier"])
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

/**
 * Used to deploy config related contracts like Accum, deaccum, verifier and notary.
 * It checks the deployed addresses, and if a contract exists, it will use the deployed instance
 * @param configurationType type of configurations
 * @param socketSigner
 */
export const setupConfig = async (
  configurationType: string,
  srcChain: string,
  destChain: string,
  socketSigner: SignerWithAddress
) => {
  localChain = srcChain
  remoteChain = destChain

  const contracts = contractNames(configurationType, localChain, remoteChain);
  if (configurationType !== contracts.integrationType)
    throw new Error("Given Configuration not supported");

  console.log(
    `Deploying contracts: SingleAccum, ${contracts.notary}, ${contracts.verifier} for ${contracts.integrationType} integration type`
  );

  if (!fs.existsSync(deployedAddressPath)) {
    throw new Error("addresses.json not found");
  }

  const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));
  if (!addresses[chainIds[localChain]] || !addresses[chainIds[remoteChain]]) {
    throw new Error("Deployed Addresses not found");
  }

  remoteConfig = addresses[chainIds[remoteChain]];
  localConfig = addresses[chainIds[localChain]];

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
  console.log("Setting config in Socket");
  const socket: Contract = await getInstance("Socket", localConfig["Socket"]);
  const socketConfig = await socket.getConfigs(chainIds[remoteChain], configurationType);

  if (socketConfig[0] === constants.AddressZero) {
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
    await storeAddresses(localConfig, chainIds[localChain]);
  }

  return { localCounter: localConfig["Counter"], remoteCounter: remoteConfig["Counter"] }
};
