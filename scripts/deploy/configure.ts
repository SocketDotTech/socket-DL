import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { attesterAddress, arbNativeBridgeIntegration, fastIntegration, timeout, slowIntegration } from "../constants/config";
import { getInstance, deployedAddressPath, storeAddresses, createObj } from "./utils";
import { constants, Contract, providers } from "ethers";
import { chainIds, getJsonRpcUrl } from "../constants/networks";
import { EthBridger, getL2Network } from "@arbitrum/sdk";
import { deployNotary, deployAccumulator, deployVerifier } from "./contracts";

const localChain: keyof typeof chainIds = "hardhat";
const remoteChain: keyof typeof chainIds = "arbitrum-goerli";
const config = fastIntegration;

const localChainProvider = new providers.JsonRpcProvider(getJsonRpcUrl(localChain))
const remoteChainProvider = new providers.JsonRpcProvider(getJsonRpcUrl(remoteChain))

if (!localChain)
  throw new Error("Provide local chain id");

if (!remoteChain)
  throw new Error("Provide remote chain id");

if (localChain === remoteChain)
  throw new Error("Wrong chains");

if (!fs.existsSync(deployedAddressPath + chainIds[localChain] + ".json") || !fs.existsSync(deployedAddressPath + chainIds[remoteChain] + ".json")) {
  throw new Error("Deployed Addresses not found");
}

let localConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + chainIds[localChain] + ".json", "utf-8"));
const remoteConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + chainIds[remoteChain] + ".json", "utf-8"))

async function getSigners() {
  const { socketOwner, counterOwner } = await getNamedAccounts();
  const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
  const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);
  return { socketSigner, counterSigner };
}

const getAccumName = (srcChain: string, destChain: string) => {
  if (srcChain.includes("arbitrum") && (destChain === "goerli" || destChain === "mainnet")) {
    return "ArbitrumL1Accum";
  } else if ((srcChain === "goerli" || srcChain === "mainnet") && destChain.includes("arbitrum")) {
    return "ArbitrumL2Accum"
  } else return "SingleAccum"
}

const getConfigurations = (srcChain: string, destChain: string) => {
  let configurations = [fastIntegration, slowIntegration]

  if (srcChain.includes("arbitrum") && (destChain === "goerli" || destChain === "mainnet")) {
    configurations.push(arbNativeBridgeIntegration);
  } else if ((srcChain === "goerli" || srcChain === "mainnet") && destChain.includes("arbitrum")) {
    configurations.push(arbNativeBridgeIntegration);
  }
  return configurations;
}

const getArbitrumInputs = async () => {
  const provider = localChain.includes("arbitrum") ? localChainProvider : remoteChainProvider;
  const network = await getL2Network(provider)
  const ethBridger = new EthBridger(network)
  const inboxAddress = ethBridger.l2Network.ethBridge.inbox

  let remoteTarget = constants.AddressZero;
  if (remoteConfig["NativeBridgeNotary"] && remoteConfig["NativeBridgeNotary"][chainIds[localChain]]) {
    remoteTarget = remoteConfig["NativeBridgeNotary"][chainIds[localChain]];
  }

  return { inboxAddress, remoteTarget }
}

const setRemoteNotary = async (socketSigner: SignerWithAddress) => {
  const accumName = getAccumName(localChain, remoteChain)
  if (accumName !== "SingleAccum") {
    const remoteAccumName = getAccumName(remoteChain, localChain);

    if (localConfig[accumName][arbNativeBridgeIntegration] && remoteConfig[remoteAccumName][arbNativeBridgeIntegration]
      && localConfig["NativeBridgeNotary"]
      && remoteConfig["NativeBridgeNotary"]
      && localConfig["NativeBridgeNotary"][chainIds[remoteChain]]
      && remoteConfig["NativeBridgeNotary"][chainIds[localChain]]
      && localConfig[accumName][arbNativeBridgeIntegration][chainIds[remoteChain]]
      && remoteConfig[remoteAccumName][arbNativeBridgeIntegration][chainIds[localChain]]
    ) {
      const localAccum = await getInstance(accumName, localConfig[accumName][arbNativeBridgeIntegration][chainIds[remoteChain]]);
      const remoteAccum = await getInstance(remoteAccumName, remoteConfig[remoteAccumName][arbNativeBridgeIntegration][chainIds[localChain]]);

      let setRemoteNotaryTx = await remoteAccum.connect(socketSigner.connect(remoteChainProvider)).setRemoteNotary(localConfig["NativeBridgeNotary"][chainIds[remoteChain]])
      await setRemoteNotaryTx.wait();

      setRemoteNotaryTx = await localAccum.connect(socketSigner.connect(localChainProvider)).setRemoteNotary(remoteConfig["NativeBridgeNotary"][chainIds[localChain]])
      await setRemoteNotaryTx.wait();
    }
  }
}

/**
 * Used to deploy config related contracts like Accum, deaccum, verifier and notary.
 * It checks the deployed addresses, and if a contract exists, it will use the deployed instance
 * @param configurationType type of configurations
 * @param socketSigner 
 */
async function setupConfig(configurationType: string, socketSigner: SignerWithAddress) {
  let notary, verifier, accum, verifierName, accumName, inbox;

  // notary
  if (configurationType === arbNativeBridgeIntegration) {
    const { inboxAddress, remoteTarget } = await getArbitrumInputs();
    inbox = inboxAddress;

    if (!localConfig["NativeBridgeNotary"] || !localConfig["NativeBridgeNotary"][chainIds[remoteChain]]) {
      notary = await deployNotary("NativeBridgeNotary", chainIds[localChain], localConfig["SignatureVerifier"], socketSigner, remoteTarget, inboxAddress)
      localConfig["NativeBridgeNotary"] = {
        [chainIds[remoteChain]]: notary.address
      };

      if (remoteConfig["NativeBridgeNotary"] && remoteConfig["NativeBridgeNotary"][chainIds[localChain]]) {
        const remoteNotary = await getInstance("NativeBridgeNotary", remoteConfig["NativeBridgeNotary"][chainIds[localChain]]);
        let updateRemoteTargetTx = await remoteNotary.connect(socketSigner.connect(remoteChainProvider)).updateRemoteTarget(notary.address);
        await updateRemoteTargetTx.wait();

        updateRemoteTargetTx = await notary.connect(socketSigner.connect(localChainProvider)).updateRemoteTarget(remoteNotary.address);
        await updateRemoteTargetTx.wait();
      }

      const grantAttesterRoleTx = await notary.connect(socketSigner).grantAttesterRole(chainIds[remoteChain], attesterAddress[localChain]);
      await grantAttesterRoleTx.wait();
    } else {
      notary = await getInstance("NativeBridgeNotary", localConfig["NativeBridgeNotary"][chainIds[remoteChain]]);
    }

    verifierName = "NativeBridgeVerifier";
    accumName = getAccumName(localChain, remoteChain)
  } else {
    if (!localConfig["AdminNotary"]) {
      notary = await deployNotary("AdminNotary", chainIds[localChain], localConfig["SignatureVerifier"], socketSigner, "", "")
      const grantAttesterRoleTx = await notary.connect(socketSigner).grantAttesterRole(chainIds[remoteChain], attesterAddress[localChain]);
      await grantAttesterRoleTx.wait();

      localConfig["AdminNotary"] = notary.address;
    } else {
      notary = await getInstance("AdminNotary", localConfig["AdminNotary"]);
    }

    verifierName = "Verifier";
    accumName = "SingleAccum";
  }

  // verifier
  if (!localConfig[verifierName]) {
    verifier = await deployVerifier(verifierName, timeout[localChain], notary, socketSigner)
    localConfig[verifierName] = verifier.address;
  } else {
    verifier = await getInstance(verifierName, localConfig[verifierName]);
  }

  // accum
  if (!localConfig[accumName] || !localConfig[accumName][configurationType] || !localConfig[accumName][configurationType][chainIds[remoteChain]]) {
    accum = await deployAccumulator(accumName, chainIds[localChain], localConfig["Socket"], notary.address, chainIds[remoteChain], inbox, socketSigner)
    localConfig = createObj(localConfig, [accumName, configurationType, chainIds[remoteChain]], accum.address)
  } else {
    accum = await getInstance(accumName, localConfig[accumName][configurationType][chainIds[remoteChain]]);
  }

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
    const { socketSigner, counterSigner } = await getSigners();
    let configurations = getConfigurations(localChain, remoteChain)

    // deploy contracts for different configurations
    for (let index = 0; index < configurations.length; index++) {
      await setupConfig(configurations[index], socketSigner);
    }
    await storeAddresses(localConfig, chainIds[localChain]);

    // setup remote notary on arbitrum accum if both side deployed
    await setRemoteNotary(socketSigner);

    // add a config to plugs on local and remote
    const counter: Contract = await getInstance("Counter", localConfig["Counter"]);
    await counter.connect(counterSigner).setSocketConfig(
      chainIds[remoteChain],
      remoteConfig["Counter"],
      config
    );
    console.log(`Set config for ${chainIds[remoteChain]} chain id!`)

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
