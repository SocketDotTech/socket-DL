import fs from "fs";
import hre from "hardhat";
import { utils } from "ethers";
import { attesterAddress, chainIds, contractNames, executorAddress } from "../constants";
import { config } from "./config";
import {
  deployedAddressPath,
  getAccumAddress,
  getInstance,
  getNotaryAddress,
  getVerifierAddress
} from "./utils";
import { assert } from "console";
import { IntegrationTypes } from "../../src";

const executorRole = "0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767";

const roleExist = async (contract, role, address) => await contract.hasRole(role, address);

const checkSocket = async (chain, remoteChain, config, configurationType, accum, verifier) => {
  await hre.changeNetwork(chain);
  const socket = await getInstance("Socket", config["Socket"]);
  let hasExecutorRole = await roleExist(socket, executorRole, executorAddress[chain]);
  assert(hasExecutorRole, `❌ Executor Role do not exist for ${chain}`);

  const socketConfig = await socket.getConfigs(chainIds[remoteChain], configurationType);
  assert(socketConfig[0] === accum, "Wrong Accum set in config");
  assert(socketConfig[1] === config["SingleDeaccum"], "Wrong Deaccum set in config");
  assert(socketConfig[2] === verifier, "Wrong Verifier set in config");
}

const checkAttesterRole = async (chain, remoteChain, notaryName, notaryAddress) => {
  await hre.changeNetwork(chain);
  const notary = await getInstance(notaryName, notaryAddress);

  let hasAttesterRole = await roleExist(notary, utils.hexZeroPad(utils.hexlify(chainIds[remoteChain]), 32), attesterAddress[chain]);
  assert(hasAttesterRole, `❌ Attester Role do not exist for ${remoteChain} on ${chain}`);
}

const checkNotary = async (chain, notaryName, notaryAddress, remoteNotaryAddress) => {
  await hre.changeNetwork(chain);
  const notary = await getInstance(notaryName, notaryAddress);

  let remoteNotary = await notary.remoteNotary();
  assert(remoteNotary === remoteNotaryAddress, `❌ Wrong notary set for ${chain}: ${notaryName}`);

  if (notaryName === "PolygonL1Notary") {
    let childTunnel = await notary.fxChildTunnel();
    assert(childTunnel === remoteNotaryAddress, `❌ Wrong childTunnel set for ${chain}`);
  }

  if (notaryName === "PolygonL2Notary") {
    let rootTunnel = await notary.fxRootTunnel();
    assert(rootTunnel === remoteNotaryAddress, `❌ Wrong rootTunnel set for ${chain}`);
  }
}

export const verifyConfig = async (
  configurationType: string,
  srcChain: string,
  destChain: string
) => {
  let localChain = srcChain
  let remoteChain = destChain

  const localContracts = contractNames(configurationType, localChain, remoteChain);
  const remoteContracts = contractNames(configurationType, remoteChain, localChain);

  if (configurationType !== localContracts.integrationType)
    throw new Error(`Wrong Configuration in configs:  deployments: ${configurationType} and configurations: ${localContracts.integrationType}`);

  if (!fs.existsSync(deployedAddressPath)) {
    throw new Error("addresses.json not found");
  }

  const addresses = JSON.parse(fs.readFileSync(deployedAddressPath, "utf-8"));
  if (!addresses[chainIds[localChain]] || !addresses[chainIds[remoteChain]]) {
    throw new Error("Deployed Addresses not found");
  }

  let remoteConfig = addresses[chainIds[remoteChain]];
  let localConfig = addresses[chainIds[localChain]];

  // contracts exist:
  // core contracts
  if (!localConfig["Hasher"] || !localConfig["SignatureVerifier"] || !localConfig["Socket"] || !localConfig["Vault"] || !localConfig["SingleDeaccum"]) {
    console.log(`❌ Core contracts do not exist for ${localChain}`);
    return;
  }

  if (!remoteConfig["Hasher"] || !remoteConfig["SignatureVerifier"] || !remoteConfig["Socket"] || !remoteConfig["Vault"] || !remoteConfig["SingleDeaccum"]) {
    console.log(`❌ Core contracts do not exist for ${remoteChain}`);
    return;
  }

  // config related contracts
  let localNotary, localAccum, localVerifier;
  let remoteNotary, remoteAccum, remoteVerifier;

  localNotary = getNotaryAddress(localContracts.notary, chainIds[remoteChain], localConfig);
  localAccum = getAccumAddress(chainIds[remoteChain], configurationType, localConfig);
  localVerifier = getVerifierAddress(localContracts.verifier, chainIds[remoteChain], localConfig);

  remoteNotary = getNotaryAddress(remoteContracts.notary, chainIds[localChain], remoteConfig);
  remoteAccum = getAccumAddress(chainIds[localChain], configurationType, remoteConfig);
  remoteVerifier = getVerifierAddress(remoteContracts.verifier, chainIds[localChain], remoteConfig);

  if (!localNotary || !localAccum || !localVerifier || !remoteNotary || !remoteAccum || !remoteVerifier) {
    console.log(`❌ Config contracts do not exist for ${configurationType}`);
    return;
  }

  console.log("✅ All contracts exist");

  // Socket: executor roles & config exists
  await checkSocket(localChain, remoteChain, localConfig, configurationType, localAccum, localVerifier)
  await checkSocket(remoteChain, localChain, remoteConfig, configurationType, remoteAccum, remoteVerifier)

  await checkAttesterRole(localChain, remoteChain, localContracts.notary, localNotary)
  await checkAttesterRole(remoteChain, localChain, remoteContracts.notary, remoteNotary)

  console.log("✅ All roles checked");
  console.log(`✅ Socket Config checked for integration type ${configurationType}`);

  // optional notary and accum settings
  if (configurationType === IntegrationTypes.nativeIntegration) {
    await checkNotary(localChain, localContracts.notary, localNotary, remoteNotary)
    await checkNotary(remoteChain, remoteContracts.notary, remoteNotary, localNotary)
  }

  console.log("✅ Checked special notaries");
};

export const main = async () => {
  try {
    for (let chain in config) {
      console.log(`\n🤖 Testing configs for ${chain}`)
      const chainSetups = config[chain];

      for (let index = 0; index < chainSetups.length; index++) {
        let remoteChain = chainSetups[index]["remoteChain"];
        let config = chainSetups[index]["config"]

        if (chain === remoteChain) throw new Error("Wrong chains");

        // verify contracts for different configurations
        for (let index = 0; index < config.length; index++) {
          console.log(`\n🚀 Testing for ${chain} and ${remoteChain} for integration type ${config[index]}`)
          await verifyConfig(config[index], chain, remoteChain);
        }
      }
    }
  } catch (error) {
    console.log("Error while verifying contracts", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
