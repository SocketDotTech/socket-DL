import fs from "fs";
import hre from "hardhat";
import { constants, utils } from "ethers";
import { transmitterAddress, chainIds, executorAddress, switchboards, proposeGasLimit, watcherAddress } from "../constants";
import { config } from "./config";
import {
  deployedAddressPath,
  getCapacitorAddress,
  getDecapacitorAddress,
  getInstance,
  getSwitchboardAddress
} from "./utils";
import { assert } from "console";
import { IntegrationTypes, NativeSwitchboard } from "../../src";

const executorRole = "0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767";

const roleExist = async (contract, role, address) => await contract.hasRole(role, address);

const checkSocket = async (chain, remoteChain, config, switchboard, capacitor, decapacitor) => {
  const socket = await getInstance("Socket", config["Socket"]);

  const executionManager = await getInstance("ExecutionManager", config["ExecutionManager"]);
  let hasExecutorRole = await roleExist(executionManager, executorRole, executorAddress[chain]);
  assert(hasExecutorRole, `❌ Executor Role do not exist for ${chain}`);

  const capacitor__ = await socket.capacitors__(switchboard, chainIds[remoteChain]);
  const decapacitor__ = await socket.decapacitors__(switchboard, chainIds[remoteChain]);

  assert(capacitor__ !== constants.AddressZero, "❌ Switchboard not registered");
  assert(capacitor__ === capacitor, "❌ Wrong Capacitor");
  assert(decapacitor__ === decapacitor, "❌ Wrong DeCapacitor");
}

const checkTransmitter = async (chain, remoteChain, transmitManagerAddr) => {
  const transmitManager = await getInstance("TransmitManager", transmitManagerAddr)

  // check role
  const hasTransmitterRole = await roleExist(transmitManager, utils.hexZeroPad(utils.hexlify(chainIds[remoteChain]), 32), transmitterAddress[chain]);
  assert(hasTransmitterRole, `❌ Transmitter Role do not exist for ${remoteChain} on ${chain}`);

  // check propose gas limit
  const proposeGasLimit__ = await transmitManager.proposeGasLimit(chainIds[remoteChain])
  assert(parseInt(proposeGasLimit__) === proposeGasLimit[remoteChain], `❌ Wrong propose gas limit set for ${remoteChain} on ${chain}`);
}

const checkOracle = async (chain, remoteChain, oracleAddr, transmitManagerAddr) => {
  const oracle = await getInstance("GasPriceOracle", oracleAddr)

  // check transmit manager
  const transmitManager = await oracle.transmitManager__();
  assert(transmitManager.toLowerCase() === transmitManagerAddr.toLowerCase(), `❌ TransmitManager not set in oracle on ${chain}`);
}

const checkSwitchboard = async (chain, remoteChain, localSwitchboard, remoteSwitchboard, configurationType) => {
  if (configurationType === IntegrationTypes.native) {
    const switchboardType = switchboards[chain][remoteChain]["switchboard"];

    if (switchboardType === NativeSwitchboard.POLYGON_L1) {
      const switchboard = await getInstance("PolygonL1Switchboard", localSwitchboard);
      let childTunnel = await switchboard.fxChildTunnel();
      assert(childTunnel === remoteSwitchboard, `❌ Wrong childTunnel set for ${chain}`);
    } else if (switchboardType === NativeSwitchboard.POLYGON_L2) {
      const switchboard = await getInstance("PolygonL2Switchboard", localSwitchboard);
      let rootTunnel = await switchboard.fxRootTunnel();
      assert(rootTunnel === remoteSwitchboard, `❌ Wrong rootTunnel set for ${chain}`);
    } else {
      const switchboard = await getInstance("ArbitrumL1Switchboard", localSwitchboard);
      const remoteSwitchboard__ = await switchboard.remoteNativeSwitchboard();
      assert(remoteSwitchboard__ === remoteSwitchboard, `❌ Wrong remote switchboard set for ${chain}`)
    }
  } else {
    const switchboard = await getInstance("FastSwitchboard", localSwitchboard);

    const executionOverheadOnChain = await switchboard.executionOverhead(chainIds[remoteChain])
    const watcherRoleSet = await switchboard.hasRole(
      utils.hexZeroPad(utils.hexlify(chainIds[remoteChain]), 32),
      watcherAddress[chain]
    );

    assert(parseInt(executionOverheadOnChain) !== 0, "❌ Execution overhead not set on switchboard")
    assert(watcherRoleSet, `❌ Watcher Role not set for ${remoteChain} on switchboard`)

    if (configurationType === IntegrationTypes.fast) {
      const attestGasLimitOnChain = await switchboard.attestGasLimit(chainIds[remoteChain]);
      assert(parseInt(attestGasLimitOnChain) !== 0, `❌ Attest gas limit is 0 for ${remoteChain} on switchboard`)
    }
  }
}

export const verifyConfig = async (
  configurationType: IntegrationTypes,
  localChain: string,
  remoteChain: string
) => {
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
  if (!localConfig["Hasher"] || !localConfig["SignatureVerifier"] || !localConfig["Socket"] || !localConfig["CapacitorFactory"] || !localConfig["GasPriceOracle"] || !localConfig["ExecutionManager"] || !localConfig["TransmitManager"]) {
    console.log(`❌ Core contracts do not exist for ${localChain}`);
    return;
  }

  if (!remoteConfig["Hasher"] || !remoteConfig["SignatureVerifier"] || !remoteConfig["Socket"] || !remoteConfig["CapacitorFactory"] || !remoteConfig["GasPriceOracle"] || !localConfig["ExecutionManager"] || !remoteConfig["TransmitManager"]) {
    console.log(`❌ Core contracts do not exist for ${remoteChain}`);
    return;
  }

  // config related contracts  
  let localSwitchboard = getSwitchboardAddress(chainIds[remoteChain], configurationType, localConfig);
  let localCapacitor = getCapacitorAddress(chainIds[remoteChain], configurationType, localConfig);
  let localDecapacitor = getDecapacitorAddress(chainIds[remoteChain], configurationType, localConfig);

  let remoteSwitchboard = getSwitchboardAddress(chainIds[localChain], configurationType, remoteConfig);
  let remoteCapacitor = getCapacitorAddress(chainIds[localChain], configurationType, remoteConfig);
  let remoteDecapacitor = getDecapacitorAddress(chainIds[localChain], configurationType, remoteConfig);

  if (!localSwitchboard || !localCapacitor || !localDecapacitor || !remoteSwitchboard || !remoteCapacitor || !remoteDecapacitor) {
    console.log(`❌ Config contracts do not exist for ${configurationType}`);
    return;
  }

  console.log("✅ All contracts exist");

  // Socket: executor roles & config exists
  await hre.changeNetwork(localChain);
  await checkSocket(localChain, remoteChain, localConfig, localSwitchboard, localCapacitor, localDecapacitor)
  await checkOracle(localChain, remoteChain, localConfig["GasPriceOracle"], localConfig["TransmitManager"])
  await checkTransmitter(localChain, remoteChain, localConfig["TransmitManager"])

  console.log("✅ All roles checked");
  console.log(`✅ Socket Config checked for integration type ${configurationType}`);

  // optional switchboard settings
  await checkSwitchboard(localChain, remoteChain, localSwitchboard, remoteSwitchboard, configurationType);
  console.log("✅ Checked switchboard settings");
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
