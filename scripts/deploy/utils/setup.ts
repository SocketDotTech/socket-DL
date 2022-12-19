import fs from "fs";
import hre from "hardhat";

import { constants, Contract, ContractTransaction, Transaction, utils } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  chainIds,
  attesterAddress,
  timeout,
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
import { IntegrationTypes } from "../../../src";

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
  let updateRemoteNotaryTx: ContractTransaction = await remoteNotary
    .connect(signers.socketSigner)
    .updateRemoteNotary(localNotary.address);

  console.log(`Sending updateRemoteNotary tx on ${remoteChain}: ${updateRemoteNotaryTx.hash}`);
  await updateRemoteNotaryTx.wait();

  await hre.changeNetwork(localChain);
  updateRemoteNotaryTx = await localNotary
    .connect(socketSigner)
    .updateRemoteNotary(remoteNotary.address);

  console.log(`Sending updateRemoteNotary tx on ${localChain}: ${updateRemoteNotaryTx.hash}`);
  await updateRemoteNotaryTx.wait();

  if (localChain === "polygon-mumbai" || remoteChain === "polygon-mumbai") await setupPolygonNotaries(localNotaryName, notary, localNotary, remoteNotary);
};

const setupPolygonNotaries = async (
  localNotaryName: string,
  remoteNotaryName: string,
  localNotary: Contract,
  remoteNotary: Contract,
) => {
  try {
    await hre.changeNetwork(remoteChain);
    let signers = await getSigners();
    if (remoteNotaryName === "PolygonL1Notary") {
      const setFxChildTunnelTx = await remoteNotary
        .connect(signers.socketSigner)
        .setFxChildTunnel(localNotary.address);

      console.log(`Sending setFxChildTunnelTx tx on ${remoteChain}: ${setFxChildTunnelTx.hash}`);
      await setFxChildTunnelTx.wait();

    } else if (remoteNotaryName === "PolygonL2Notary") {
      const setFxRootTunnelTx = await remoteNotary
        .connect(signers.socketSigner)
        .setFxRootTunnel(localNotary.address);

      console.log(`Sending setFxRootTunnelTx tx on ${remoteChain}: ${setFxRootTunnelTx.hash}`);
      await setFxRootTunnelTx.wait();
    }

    await hre.changeNetwork(localChain);
    signers = await getSigners();
    if (localNotaryName === "PolygonL1Notary") {
      const setFxChildTunnelTx = await localNotary.connect(signers.socketSigner)
        .setFxChildTunnel(remoteNotary.address);

      console.log(`Sending setFxChildTunnelTx tx on ${localChain}: ${setFxChildTunnelTx.hash}`);
      await setFxChildTunnelTx.wait();

    } else if (localNotaryName === "PolygonL2Notary") {
      const setFxRootTunnelTx = await localNotary.connect(signers.socketSigner)
        .setFxRootTunnel(remoteNotary.address);

      console.log(`Sending setFxRootTunnelTx tx on ${localChain}: ${setFxRootTunnelTx.hash}`);
      await setFxRootTunnelTx.wait();
    }
  } catch (error) {
    throw new Error(
      `Error while setting up polygon notaries: ${error}`
    );
  }
}

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
      if (!remoteNotary) remoteNotary = constants.AddressZero;

      notary = await deployNotary(
        notaryName,
        localChain,
        localConfig["SignatureVerifier"],
        remoteNotary,
        socketSigner
      );

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

    const hasRole = await notary.hasRole(utils.hexZeroPad(utils.hexlify(chainIds[remoteChain]), 32), attesterAddress[localChain]);
    if (!hasRole) {
      const grantAttesterRoleTx = await notary
        .connect(socketSigner)
        .grantAttesterRole(chainIds[remoteChain], attesterAddress[localChain]);

      console.log(`Sending grantAttesterRoleTx on ${localChain}: ${grantAttesterRoleTx.hash}`);
      await grantAttesterRoleTx.wait();
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
  console.log(`Notary deployed at: ${notary.address}`)
  await storeAddresses(localConfig, chainIds[localChain]);

  let verifier = await deployLocalVerifier(
    configurationType,
    contracts.verifier,
    notary.address,
    socketSigner
  );
  console.log(`Verifier deployed at: ${verifier.address}`)
  await storeAddresses(localConfig, chainIds[localChain]);

  let accum = await deployLocalAccum(
    configurationType,
    notary.address,
    socketSigner
  );
  console.log(`Accum deployed at: ${accum.address}`)
  await storeAddresses(localConfig, chainIds[localChain]);

  // optional notary and accum settings
  if (
    configurationType !== IntegrationTypes.fastIntegration &&
    configurationType !== IntegrationTypes.slowIntegration
  ) {
    await setupContracts(notary, contracts.notary, socketSigner);
  }

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
    console.log(`Sending addConfigTx on ${localChain}: ${addConfigTx.hash}`);
    await addConfigTx.wait();
    await storeAddresses(localConfig, chainIds[localChain]);
  }

  return { localCounter: localConfig["Counter"], remoteCounter: remoteConfig["Counter"] }
};
