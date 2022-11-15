import fs from "fs";
import hre, { getNamedAccounts, ethers } from "hardhat";
import { constants, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { chainIds, attesterAddress, arbNativeBridgeIntegration, fastIntegration, timeout, slowIntegration, optimismNativeBridgeIntegration, polygonNativeBridgeIntegration } from "../constants";
import { getInstance, deployedAddressPath, storeAddresses, createObj, getChainId } from "./utils";
import { deployNotary, deployAccumulator, deployVerifier } from "./contracts";
import { ChainSocketAddresses } from "./types";

const localChain: keyof typeof chainIds = "";
const remoteChain: keyof typeof chainIds = "";
const config = [];
const configForCounter = "";

if (!localChain)
  throw new Error("Provide local chain id");

if (!remoteChain)
  throw new Error("Provide remote chain id");

if (localChain === remoteChain)
  throw new Error("Wrong chains");

if (!fs.existsSync(deployedAddressPath)) {
  throw new Error("addresses.json not found");
}

if (config.length === 0 && configForCounter === "")
  throw new Error("No configuration provided");

const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));

if (
  !addresses[chainIds[localChain]] || !addresses[chainIds[remoteChain]]
) {
  throw new Error("Deployed Addresses not found");
}

const remoteConfig: ChainSocketAddresses = addresses[chainIds[remoteChain]];
let localConfig: ChainSocketAddresses = addresses[chainIds[localChain]];

const getSigners = async () => {
  const { socketOwner, counterOwner } = await getNamedAccounts();
  const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
  const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);
  return { socketSigner, counterSigner };
}

const contractNames = (integrationType: string, srcChain: string, dstChain: string) => {
  let accum = {
    "arbitrum-goerli": {
      "goerli": {
        integrationType: arbNativeBridgeIntegration,
        accum: "ArbitrumL2Accum",
        verifier: "NativeBridgeVerifier",
        notary: "ArbitrumReceiver",
      }
    },
    "arbitrum-mainnet": {
      "mainnet": {
        integrationType: arbNativeBridgeIntegration,
        accum: "ArbitrumL2Accum",
        verifier: "NativeBridgeVerifier",
        notary: "ArbitrumReceiver",
      }
    },
    "optimism-mainnet": {
      "mainnet": {
        integrationType: optimismNativeBridgeIntegration,
        accum: "OptimismAccum",
        verifier: "NativeBridgeVerifier",
        notary: "OptimismReceiver",
      }
    },
    "optimism-goerli": {
      "goerli": {
        integrationType: optimismNativeBridgeIntegration,
        accum: "OptimismAccum",
        verifier: "NativeBridgeVerifier",
        notary: "OptimismReceiver",
      }
    },
    "polygon-mainnet": {
      "mainnet": {
        integrationType: polygonNativeBridgeIntegration,
        accum: "PolygonChildAccum",
        verifier: "NativeBridgeVerifier",
        notary: "PolygonChildReceiver",
      }
    },
    "polygon-mumbai": {
      "goerli": {
        integrationType: polygonNativeBridgeIntegration,
        accum: "PolygonChildAccum",
        verifier: "NativeBridgeVerifier",
        notary: "PolygonChildReceiver",
      }
    },
    "goerli": {
      "arbitrum-goerli": {
        integrationType: arbNativeBridgeIntegration,
        accum: "ArbitrumL1Accum",
        verifier: "NativeBridgeVerifier",
        notary: "ArbitrumReceiver",
      },
      "optimism-goerli": {
        integrationType: optimismNativeBridgeIntegration,
        accum: "OptimismAccum",
        verifier: "NativeBridgeVerifier",
        notary: "OptimismReceiver",
      },
      "polygon-mumbai": {
        integrationType: polygonNativeBridgeIntegration,
        accum: "PolygonRootAccum",
        verifier: "NativeBridgeVerifier",
        notary: "PolygonRootReceiver"
      }
    },
    "mainnet": {
      "arbitrum-mainnet": {
        integrationType: arbNativeBridgeIntegration,
        accum: "ArbitrumL1Accum",
        verifier: "NativeBridgeVerifier",
        notary: "ArbitrumReceiver",
      },
      "optimism-mainnet": {
        integrationType: optimismNativeBridgeIntegration,
        accum: "OptimismAccum",
        verifier: "NativeBridgeVerifier",
        notary: "OptimismReceiver",
      },
      "polygon-mainnet": {
        integrationType: polygonNativeBridgeIntegration,
        accum: "PolygonRootAccum",
        verifier: "NativeBridgeVerifier",
        notary: "PolygonRootReceiver"
      }
    }
  }

  const defaultConfig = { integrationType, accum: "SingleAccum", verifier: "Verifier", notary: "AdminNotary" };
  if (integrationType === fastIntegration || integrationType === slowIntegration) return defaultConfig;
  if (!accum[srcChain] || !accum[srcChain][dstChain]) return defaultConfig;

  return accum[srcChain][dstChain];
}

const remoteTarget = (notaryName: string) => {
  let remoteTarget = constants.AddressZero;
  if (remoteConfig[notaryName] && remoteConfig[notaryName][chainIds[localChain]]) {
    remoteTarget = remoteConfig[notaryName][chainIds[localChain]];
  }

  return remoteTarget
}

const deployLocalNotary = async (notaryName, socketSigner) => {
  let notary;
  if (!localConfig[notaryName]?.[chainIds[remoteChain]]) {
    notary = await deployNotary(notaryName, localChain, localConfig["SignatureVerifier"], remoteTarget(notaryName), socketSigner)
    const grantAttesterRoleTx = await notary.connect(socketSigner).grantAttesterRole(chainIds[remoteChain], attesterAddress[localChain]);
    await grantAttesterRoleTx.wait();

    localConfig = createObj(localConfig, [notaryName, chainIds[remoteChain]], notary.address);
  } else {
    notary = await getInstance(notaryName, localConfig[notaryName]);
  }
  return notary;
}

const deployLocalAccum = async (accumName, configurationType, notaryAddress, socketSigner) => {
  try {
    let accum;
    if (!localConfig[accumName]?.[configurationType]?.[chainIds[remoteChain]]) {
      accum = await deployAccumulator(accumName, localChain, localConfig["Socket"], notaryAddress, remoteChain, socketSigner)
      localConfig = createObj(localConfig, [accumName, configurationType, chainIds[remoteChain]], accum.address)
    } else {
      accum = await getInstance(accumName, localConfig[accumName][configurationType][chainIds[remoteChain]]);
    }

    return accum;
  } catch (error) {
    throw new Error(`Error while deploying accum contract: accumName`)
  }
}

const deployLocalVerifier = async (verifierName, notaryAddress, socketSigner) => {
  try {
    let verifier;
    if (!localConfig[verifierName]) {
      verifier = await deployVerifier(verifierName, timeout[localChain], notaryAddress, socketSigner)
      localConfig[verifierName] = verifier.address;
    } else {
      verifier = await getInstance(verifierName, localConfig[verifierName]);
    }

    return verifier;
  } catch (error) {
    throw new Error(`Error while deploying accum contract: accumName`)
  }
}

const setupContracts = async (localNotary, localAccum, socketSigner) => {
  // check if remote notary and accum exists
  const { notary, accum, integrationType } = contractNames("", remoteChain, localChain);

  const remoteNotaryAddress = remoteConfig[notary]?.[chainIds[localChain]];
  const remoteAccumAddress = remoteConfig[accum]?.[integrationType]?.[chainIds[localChain]];

  if (!remoteNotaryAddress || !remoteAccumAddress) return;

  const remoteNotary = await getInstance(notary, remoteNotaryAddress);
  const remoteAccum = await getInstance(accum, remoteAccumAddress);

  await hre.changeNetwork(remoteChain);
  const signers = await getSigners();
  let updateRemoteTargetTx = await remoteNotary.connect(signers.socketSigner).updateRemoteTarget(localAccum.address);
  await updateRemoteTargetTx.wait();

  let setRemoteNotaryTx = await remoteAccum.connect(signers.socketSigner).setRemoteNotary(localNotary.address)
  await setRemoteNotaryTx.wait();

  await hre.changeNetwork(localChain);
  updateRemoteTargetTx = await localNotary.connect(socketSigner).updateRemoteTarget(remoteAccumAddress);
  await updateRemoteTargetTx.wait();

  setRemoteNotaryTx = await localAccum.connect(socketSigner).setRemoteNotary(remoteNotaryAddress)
  await setRemoteNotaryTx.wait();
}

/**
 * Used to deploy config related contracts like Accum, deaccum, verifier and notary.
 * It checks the deployed addresses, and if a contract exists, it will use the deployed instance
 * @param configurationType type of configurations
 * @param socketSigner 
 */
const setupConfig = async (configurationType: string, socketSigner: SignerWithAddress) => {
  const contracts = contractNames(configurationType, localChain, remoteChain)
  if (configurationType !== contracts.integrationType) throw new Error("Given Configuration not supported");

  console.log(`Deploying following contracts ${contracts}`);

  let notary = await deployLocalNotary(contracts.notary, socketSigner);
  let verifier = await deployLocalVerifier(contracts.verifier, notary.address, socketSigner);
  let accum = await deployLocalAccum(contracts.accum, configurationType, notary.address, socketSigner);

  // optional notary and accum settings
  if (configurationType !== fastIntegration && configurationType !== slowIntegration) await setupContracts(notary, accum, socketSigner);

  // add config to socket
  const socket: Contract = await getInstance("Socket", localConfig["Socket"]);
  const addConfigTx = await socket.connect(socketSigner).addConfig(
    chainIds[remoteChain],
    accum.address,
    localConfig["SingleDeaccum"],
    verifier.address,
    configurationType
  );
  await addConfigTx.wait();
}

export const main = async () => {
  try {
    const chainId = await getChainId();
    if (chainId !== chainIds[localChain]) throw new Error("Wrong network connected");

    const { socketSigner, counterSigner } = await getSigners();

    // deploy contracts for different configurations
    for (let index = 0; index < config.length; index++) {
      await setupConfig(config[index], socketSigner);
    }

    await storeAddresses(localConfig, chainIds[localChain]);

    // add a config to plugs on local and remote
    const counter: Contract = await getInstance("Counter", localConfig["Counter"]);
    await counter.connect(counterSigner).setSocketConfig(
      chainIds[remoteChain],
      remoteConfig["Counter"],
      configForCounter
    );
    console.log(`Set config ${configForCounter} for ${chainIds[remoteChain]} chain id!`)
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
