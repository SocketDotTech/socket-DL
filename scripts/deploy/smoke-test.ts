import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import hre from "hardhat";
import { constants } from "ethers";
import { switchboards, getDefaultIntegrationType } from "../constants";
import {
  executorAddresses,
  mode,
  socketOwner,
  transmitterAddresses,
  watcherAddresses,
} from "./config/config";
import {
  getCapacitorAddress,
  getChainRoleHash,
  getDecapacitorAddress,
  getInstance,
  getRoleHash,
  getSwitchboardAddress,
} from "./utils";
import { assert } from "console";
import {
  CORE_CONTRACTS,
  IntegrationTypes,
  NativeSwitchboard,
  hardhatChainNameToSlug,
  getAllAddresses,
} from "../../src";

async function checkNative(
  contractAddr,
  localChain,
  remoteChain,
  remoteSwitchboard
) {
  const contractName = switchboards[localChain][remoteChain];
  const switchboard = await getInstance(contractName, contractAddr);

  if (contractName === NativeSwitchboard.POLYGON_L1) {
    const remoteSb = await switchboard.fxChildTunnel();
    assert(remoteSb === remoteSwitchboard, "❌ wrong fxChildTunnel set");
  } else if (contractName === NativeSwitchboard.POLYGON_L2) {
    const remoteSb = await switchboard.fxRootTunnel();
    assert(remoteSb === remoteSwitchboard, "❌ wrong fxRootTunnel set");
  } else {
    const remoteSb = await switchboard.remoteNativeSwitchboard();
    assert(remoteSb === remoteSwitchboard, "❌ wrong remote switchboard set");
  }
}

async function checkFast(contractAddr, localChain, remoteChain) {
  const switchboard = await getInstance("FastSwitchboard", contractAddr);

  let hasRole = await switchboard["hasRole(bytes32,address)"](
    getChainRoleHash("WATCHER_ROLE", hardhatChainNameToSlug[remoteChain]),
    watcherAddresses[mode]
  );
  assert(hasRole, `❌ FastSwitchboard has wrong TRIP_ROLE ${remoteChain}`);
}

async function checkDefault(contractAddr, localChain, remoteChain) {
  const switchboard = await getInstance("FastSwitchboard", contractAddr);

  // check roles
  let hasRole = await switchboard["hasRole(bytes32,address)"](
    getChainRoleHash("TRIP_ROLE", hardhatChainNameToSlug[remoteChain]),
    transmitterAddresses[mode]
  );
  assert(hasRole, `❌ Switchboard has wrong TRIP_ROLE ${remoteChain}`);

  hasRole = await switchboard["hasRole(bytes32,address)"](
    getChainRoleHash("UN_TRIP_ROLE", hardhatChainNameToSlug[remoteChain]),
    transmitterAddresses[mode]
  );
  assert(hasRole, `❌ Switchboard has wrong UN_TRIP_ROLE ${remoteChain}`);
}

async function checkSwitchboardRoles(chain, contractAddr) {
  const switchboard = await getInstance("PolygonL1Switchboard", contractAddr);

  // check roles
  let hasRole = await switchboard["hasRole(bytes32,address)"](
    getRoleHash("GOVERNANCE_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ Switchboard has wrong governance address ${chain}`);

  hasRole = await switchboard["hasRole(bytes32,address)"](
    getRoleHash("RESCUE_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ Switchboard has wrong rescue address ${chain}`);

  hasRole = await switchboard["hasRole(bytes32,address)"](
    getRoleHash("WITHDRAW_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ Switchboard has wrong withdraw role address ${chain}`);

  hasRole = await switchboard["hasRole(bytes32,address)"](
    getRoleHash("TRIP_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ Switchboard has wrong trip role address ${chain}`);

  hasRole = await switchboard["hasRole(bytes32,address)"](
    getRoleHash("UN_TRIP_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ Switchboard has wrong unTrip role address ${chain}`);
}

async function checkSwitchboardRegistration(
  siblingChain,
  socketAddr,
  switchboard,
  capacitor,
  decapacitor
) {
  const socket = await getInstance(CORE_CONTRACTS.Socket, socketAddr);

  const capacitor__ = await socket.capacitors__(
    switchboard,
    hardhatChainNameToSlug[siblingChain]
  );
  const decapacitor__ = await socket.decapacitors__(
    switchboard,
    hardhatChainNameToSlug[siblingChain]
  );

  assert(
    capacitor__ !== constants.AddressZero,
    "❌ Switchboard not registered"
  );
  assert(capacitor__ === capacitor, "❌ Wrong Capacitor");
  assert(decapacitor__ === decapacitor, "❌ Wrong DeCapacitor");
}

async function checkCounter(
  siblingSlug,
  localConfig,
  remoteConfig,
  integrationType
) {
  const socket = await getInstance(
    CORE_CONTRACTS.Socket,
    localConfig[CORE_CONTRACTS.Socket]
  );

  // check config
  const config = await socket.getPlugConfig(
    localConfig["Counter"],
    hardhatChainNameToSlug[siblingSlug]
  );

  if (
    !localConfig?.["integrations"]?.[hardhatChainNameToSlug[siblingSlug]]?.[
      integrationType
    ]
  ) {
    console.log(
      `❌ No integration found for ${siblingSlug} for ${integrationType}`
    );
    return;
  }

  const outboundSb =
    localConfig["integrations"][hardhatChainNameToSlug[siblingSlug]][
      integrationType
    ];
  assert(
    config.siblingPlug == remoteConfig["Counter"] &&
      config.inboundSwitchboard__ == outboundSb["switchboard"] &&
      config.outboundSwitchboard__ == outboundSb["switchboard"] &&
      config.capacitor__ == outboundSb["capacitor"] &&
      config.decapacitor__ == outboundSb["decapacitor"],
    `❌ Socket has wrong config set for ${siblingSlug}`
  );
}

async function checkTransmitManager(chain, contractAddr, remoteChain) {
  const transmitManager = await getInstance(
    CORE_CONTRACTS.TransmitManager,
    contractAddr
  );

  // check roles
  let hasRole = await transmitManager["hasRole(bytes32,address)"](
    getRoleHash("GOVERNANCE_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ TransmitManager has wrong governance address ${chain}`);

  hasRole = await transmitManager["hasRole(bytes32,address)"](
    getRoleHash("RESCUE_ROLE"),
    socketOwner
  );

  assert(hasRole, `❌ TransmitManager has wrong rescue address ${chain}`);

  hasRole = await transmitManager["hasRole(bytes32,address)"](
    getRoleHash("WITHDRAW_ROLE"),
    socketOwner
  );

  assert(
    hasRole,
    `❌ TransmitManager has wrong withdraw role address ${chain}`
  );

  hasRole = await transmitManager["hasRole(bytes32,address)"](
    getChainRoleHash("TRANSMITTER_ROLE", hardhatChainNameToSlug[chain]),
    transmitterAddresses[mode]
  );
  assert(
    hasRole,
    `❌ TransmitManager has wrong transmitter address for ${chain}`
  );

  hasRole = await transmitManager["hasRole(bytes32,address)"](
    getChainRoleHash("TRANSMITTER_ROLE", hardhatChainNameToSlug[remoteChain]),
    transmitterAddresses[mode]
  );
  assert(
    hasRole,
    `❌ TransmitManager has wrong transmitter address for ${remoteChain}`
  );
}

async function checkExecutionManager(chain, contractAddr) {
  const executionManager = await getInstance(
    CORE_CONTRACTS.ExecutionManager,
    contractAddr
  );

  // check roles
  let hasRole = await executionManager["hasRole(bytes32,address)"](
    getRoleHash("GOVERNANCE_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ ExecutionManager has wrong governance address ${chain}`);

  hasRole = await executionManager["hasRole(bytes32,address)"](
    getRoleHash("RESCUE_ROLE"),
    socketOwner
  );

  assert(hasRole, `❌ ExecutionManager has wrong rescue address ${chain}`);

  hasRole = await executionManager["hasRole(bytes32,address)"](
    getRoleHash("WITHDRAW_ROLE"),
    socketOwner
  );

  assert(
    hasRole,
    `❌ ExecutionManager has wrong withdraw role address ${chain}`
  );

  hasRole = await executionManager["hasRole(bytes32,address)"](
    getRoleHash("EXECUTOR_ROLE"),
    executorAddresses[mode]
  );
  assert(hasRole, `❌ ExecutionManager has wrong executor address ${chain}`);
}

async function checkSocket(chain, socketAddr) {
  const socket = await getInstance(CORE_CONTRACTS.Socket, socketAddr);

  // check roles
  let hasRole = await socket["hasRole(bytes32,address)"](
    getRoleHash("GOVERNANCE_ROLE"),
    socketOwner
  );
  assert(hasRole, `❌ Socket has wrong governance address ${chain}`);

  hasRole = await socket["hasRole(bytes32,address)"](
    getRoleHash("RESCUE_ROLE"),
    socketOwner
  );

  assert(hasRole, `❌ Socket has wrong rescue address ${chain}`);
}

async function checkIntegration(
  configurationType: IntegrationTypes,
  localChain: string,
  remoteChain: string,
  localConfig,
  remoteConfig
) {
  // config related contracts
  let localSwitchboard = getSwitchboardAddress(
    hardhatChainNameToSlug[remoteChain],
    configurationType,
    localConfig
  );
  let localCapacitor = getCapacitorAddress(
    hardhatChainNameToSlug[remoteChain],
    configurationType,
    localConfig
  );
  let localDecapacitor = getDecapacitorAddress(
    hardhatChainNameToSlug[remoteChain],
    configurationType,
    localConfig
  );

  let remoteSwitchboard = getSwitchboardAddress(
    hardhatChainNameToSlug[localChain],
    configurationType,
    remoteConfig
  );
  let remoteCapacitor = getCapacitorAddress(
    hardhatChainNameToSlug[localChain],
    configurationType,
    remoteConfig
  );
  let remoteDecapacitor = getDecapacitorAddress(
    hardhatChainNameToSlug[localChain],
    configurationType,
    remoteConfig
  );

  if (!localSwitchboard || !localCapacitor || !localDecapacitor) {
    console.log(
      `❌ Config contracts do not exist for ${configurationType} on ${localChain}`
    );
    return { localSwitchboard, remoteSwitchboard };
  }

  if (!remoteSwitchboard || !remoteCapacitor || !remoteDecapacitor) {
    console.log(
      `❌ Config contracts do not exist for ${configurationType} on ${remoteChain}`
    );
    return { localSwitchboard, remoteSwitchboard };
  }
  console.log("✅ All contracts exist");

  await hre.changeNetwork(remoteChain);
  await checkSwitchboardRegistration(
    localChain,
    remoteConfig[CORE_CONTRACTS.Socket],
    remoteSwitchboard,
    remoteCapacitor,
    remoteDecapacitor
  );

  await hre.changeNetwork(localChain);
  await checkSwitchboardRegistration(
    remoteChain,
    localConfig[CORE_CONTRACTS.Socket],
    localSwitchboard,
    localCapacitor,
    localDecapacitor
  );
  console.log("✅ Switchboards registered");

  return { localSwitchboard, remoteSwitchboard };
}

function checkCoreContractAddress(
  localConfig,
  remoteConfig,
  localChain,
  remoteChain
) {
  // contracts exist:
  // core contracts
  if (
    !localConfig["Counter"] ||
    !localConfig[CORE_CONTRACTS.CapacitorFactory] ||
    !localConfig[CORE_CONTRACTS.ExecutionManager] ||
    !localConfig[CORE_CONTRACTS.Hasher] ||
    !localConfig[CORE_CONTRACTS.SignatureVerifier] ||
    !localConfig[CORE_CONTRACTS.Socket] ||
    !localConfig[CORE_CONTRACTS.TransmitManager] ||
    !localConfig["SocketBatcher"]
  ) {
    console.log(`❌ Core contracts do not exist for ${localChain}`);
    return;
  }

  if (
    !remoteConfig["Counter"] ||
    !remoteConfig[CORE_CONTRACTS.CapacitorFactory] ||
    !remoteConfig[CORE_CONTRACTS.ExecutionManager] ||
    !remoteConfig[CORE_CONTRACTS.Hasher] ||
    !remoteConfig[CORE_CONTRACTS.SignatureVerifier] ||
    !remoteConfig[CORE_CONTRACTS.Socket] ||
    !remoteConfig[CORE_CONTRACTS.TransmitManager] ||
    !remoteConfig["SocketBatcher"]
  ) {
    console.log(`❌ Core contracts do not exist for ${remoteChain}`);
    return;
  }
}

export const main = async () => {
  try {
    const addresses = getAllAddresses(mode);

    for (let chain in addresses) {
      console.log(`\n🤖 Testing configs for ${chain}`);
      const chainSetups = addresses[chain];

      for (let index = 0; index < chainSetups.length; index++) {
        let remoteChain = chainSetups[index]["remoteChain"];
        let config = chainSetups[index]["config"];

        if (chain === remoteChain) throw new Error("Wrong chains");

        let remoteConfig = addresses[hardhatChainNameToSlug[remoteChain]];
        let localConfig = addresses[hardhatChainNameToSlug[chain]];

        await hre.changeNetwork(chain);
        checkCoreContractAddress(localConfig, remoteConfig, chain, remoteChain);
        console.log("✅ Checked Core contracts");

        await checkSocket(chain, localConfig[CORE_CONTRACTS.Socket]);
        console.log("✅ Checked Socket");

        await checkExecutionManager(
          chain,
          localConfig[CORE_CONTRACTS.ExecutionManager]
        );
        console.log("✅ Checked ExecutionManager");

        await checkTransmitManager(
          chain,
          localConfig[CORE_CONTRACTS.TransmitManager],
          remoteChain
        );
        console.log("✅ Checked TransmitManager");

        await checkCounter(
          remoteChain,
          localConfig,
          remoteConfig,
          getDefaultIntegrationType(chain, remoteConfig)
        );
        console.log("✅ Checked Counter");

        // verify contracts for different configurations
        for (let index = 0; index < config.length; index++) {
          console.log(
            `\n🚀 Testing for ${chain} and ${remoteChain} for integration type ${config[index]}`
          );

          const { localSwitchboard, remoteSwitchboard } =
            await checkIntegration(
              config[index],
              chain,
              remoteChain,
              localConfig,
              remoteConfig
            );
          await checkSwitchboardRoles(chain, localSwitchboard);

          if (config === IntegrationTypes.native) {
            await checkNative(
              localSwitchboard,
              chain,
              remoteChain,
              remoteSwitchboard
            );
          } else {
            await checkDefault(localSwitchboard, chain, remoteChain);
            if (config === IntegrationTypes.fast) {
              await checkFast(localSwitchboard, chain, remoteChain);
            }
          }
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
