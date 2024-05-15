import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ROLES, CORE_CONTRACTS, ChainSlug } from "../../src";
import {
  mode,
  overrides,
} from "./config";
import constants from "./utils/kinto/constants.json";
import { getAddresses, getInstance, getRoleHash } from "./utils";
import { handleOps, isKinto, whitelistApp } from "./utils/kinto/kinto";
import { Wallet } from "ethers";
import { getProviderFromChainSlug } from "../constants";

// TODO: maybe modify so in the case of the SocketBatcher, we only grant the role to the funding wallet and not to all of them
// since it has the withdrawals function.
const main = async () => {
  const addresses = await getAddresses(constants.KINTO_DATA.chainId, mode);

  const whitelistedContracts = [
    "CapacitorSimulator",
    CORE_CONTRACTS.Socket,
    CORE_CONTRACTS.ExecutionManager,
    CORE_CONTRACTS.TransmitManager,
    // CORE_CONTRACTS.FastSwitchboard, // No need
    CORE_CONTRACTS.OptimisticSwitchboard,
    CORE_CONTRACTS.SocketBatcher,
    "SocketSimulator",
    "SimulatorUtils",
    "SwitchboardSimulator",
  ];

  const relayers = [
    "0x0240c3151FE3e5bdBB1894F59C5Ed9fE71ba0a5E", // funder
    "0x090FC3eaD2E5e81d3c0FA2E45636Ef003baB9DFB",
    "0x07ca54b301dECA9C8Bc9AF4e4Cd6A87531018031",
    "0xA214AED7Cf1982D5e342Fd93711a49153623f953",
    "0x78246aC69cce0d90A366B2d52064a88bb4aD8467",
    "0x1612Ba11DC7Df706b20CD1f10485a401510b733D",
    "0x023C34fb3Ed5880C865CF918774Ca12440dcB8BE",
    "0xe57F05B668a660730c6E53e7219dAaEE816c6A42",
    "0xf46b7b71Bf024c4a7A102FB570C89b03d3dDEc92",
    "0xBc8b8f4e21d51DBdCD0E453d7D689ccb0D3e2B7b",
    "0x54d3FD4D39Dbdc19cd5D1f7C768bFd64b9b083Fa",
    "0x3dD9202eEF026d70fA941aaDec376D334c264655",
    "0x7cD375aB19061bD3b5Ae28912883AaBE8108b633",
    "0x6fB68De2F072f720BDAc80E8BCe9D124E44c33a5",
    "0xdE4e383CaF7659C08AbC3Ce29539D8CA22ee9c71",
    "0xeD85Fa16FE6bF65CEf63a7FCa08f2366Dc224Dd4",
    "0x26cE14a363Cd7D52A02B996dbaC9d7eF47E46662",
    "0xB49d1bC43e1Ae7081eF8eFc1B550C85e057da558",
    "0xb6799BaEE97CF905D50DBD296c4e26253751eBd1",
    "0xE83141Cc5A9d04b0F8b2A98cD32c27E0FCBa2Dd4",
    "0x5A4c33DC6c8a53cb1Ba989eE62dcaE09036C7682",
  ];

  const contracts = [
    addresses[CORE_CONTRACTS.Socket],
  ];

  const connectors = [
  ];

  const allAddresses = [
    ...relayers,
    ...contracts,
    ...connectors,
  ]

  const provider = getProviderFromChainSlug(constants.KINTO_DATA.chainId as any as ChainSlug);
  const wallet = new Wallet(process.env.SOCKET_SIGNER_KEY!, provider);

  for (const contract of whitelistedContracts) {
    // for each relayer, grant SOCKET_RELAYER_ROLE
    const userSpecificRoles = allAddresses.map((relayer) => ({
      userAddress: relayer,
      filterRoles: [ROLES.SOCKET_RELAYER_ROLE],
    }));    
    console.log(`\nWhitelisting ${contract} @ ${addresses[contract]}...`);
    await whitelistApp(addresses[contract], wallet);

    const instance = (await getInstance(contract === "CapacitorSimulator" ? "SingleCapacitor" : contract, addresses[contract])).connect(wallet);

    for (const role of userSpecificRoles) {
      console.log(`Granting ${role.filterRoles} to ${role.userAddress} on contract ${contract}...`);
      const txRequest =
        await instance.populateTransaction.grantRole(
          getRoleHash(ROLES.SOCKET_RELAYER_ROLE),
          role.userAddress,
          {
            ...overrides(await wallet.getChainId()),
          }
        );

      const registerTx = await handleOps([txRequest], wallet);
      console.log(`Successfully granted ${role.filterRoles} to ${role.userAddress} on contract ${contract}. Transaction hash: ${registerTx.transactionHash}`);
    }
  }

  // add each relayer to the allowlist of the SocketBatcher
  for (const relayer of relayers) {
    const socketBatcher = (await getInstance(CORE_CONTRACTS.SocketBatcher, addresses[CORE_CONTRACTS.SocketBatcher])).connect(wallet);
    const txRequest = await socketBatcher.populateTransaction.allowlist(relayer, true, {
      ...overrides(await wallet.getChainId()),
    });
    const registerTx = await handleOps([txRequest], wallet);
    console.log(`Successfully added ${relayer} to the allowlist of SocketBatcher. Transaction hash: ${registerTx.transactionHash}`);
  }
  
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
