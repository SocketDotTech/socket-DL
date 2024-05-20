import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ChainSlug, DeploymentMode, CORE_CONTRACTS, version } from "../../src";
import { BigNumberish, utils } from "ethers";
import chainConfig from "../../chainConfig.json";

export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

if (!process.env.SOCKET_OWNER_ADDRESS)
  throw Error("Socket owner address not present");
export const socketOwner = process.env.SOCKET_OWNER_ADDRESS;

console.log(
  "================================================================================================================"
);
console.log("");
console.log(`Mode: ${mode}`);
console.log(`Version: ${version[mode]}`);
console.log(`Owner: ${socketOwner}`);
console.log("");
console.log(
  `Make sure ${mode}_addresses.json and ${mode}_verification.json is cleared for given networks if redeploying!!`
);
console.log("");
console.log(
  "================================================================================================================"
);

export const chains: Array<ChainSlug> = [
  // ChainSlug.GOERLI,
  // ChainSlug.ARBITRUM_SEPOLIA,
  // ChainSlug.OPTIMISM_SEPOLIA,
  ChainSlug.KINTO,
  // ChainSlug.POLYGON_MUMBAI,
  // ChainSlug.SX_NETWORK_TESTNET,
  // ChainSlug.SX_NETWORK,
  // ChainSlug.MODE_TESTNET,
  // ChainSlug.VICTION_TESTNET,
  // ChainSlug.BSC_TESTNET,
  // ChainSlug.AEVO_TESTNET,
  // ChainSlug.LYRA_TESTNET,
  // ChainSlug.SEPOLIA,
  // ChainSlug.XAI_TESTNET,
  // ChainSlug.CDK_TESTNET,
  // ChainSlug.AEVO,
  // ChainSlug.MAINNET,
  // ChainSlug.ARBITRUM,
  // ChainSlug.OPTIMISM,
  // ChainSlug.POLYGON_MAINNET,
  // ChainSlug.LYRA,
  // ChainSlug.BSC,
  // ChainSlug.BASE,
  // ChainSlug.MODE,
  // ChainSlug.ANCIENT8_TESTNET,
  // ChainSlug.ANCIENT8_TESTNET2,
  // ChainSlug.SYNDR_SEPOLIA_L3,
  // ChainSlug.HOOK_TESTNET,
  // ChainSlug.HOOK,
  // ChainSlug.PARALLEL,
  // ChainSlug.MANTLE,
  // ChainSlug.REYA_CRONOS,
  // ChainSlug.REYA,
  // ChainSlug.POLYNOMIAL_TESTNET,
];

export const executionManagerVersion = CORE_CONTRACTS.ExecutionManager;
export const sendTransaction = true;
export const newRoleStatus = true;
export const filterChains: number[] = chains;
export const filterSiblingChains: number[] = [
  ChainSlug.ARBITRUM,
  ChainSlug.BASE,
  ChainSlug.MAINNET,
  ChainSlug.OPTIMISM,
];
export const capacitorType = 1;
export const maxPacketLength = 1;
export const initialPacketCount = 0;

export const gasLimit = undefined;
export const gasPrice = undefined;
export const type = 0;

const MSG_VALUE_MAX_THRESHOLD = utils.parseEther("0.001");
export const msgValueMaxThreshold = (chain: ChainSlug): BigNumberish => {
  if (chainConfig[chain] && chainConfig[chain].msgValueMaxThreshold)
    return chainConfig[chain].msgValueMaxThreshold!;
  return MSG_VALUE_MAX_THRESHOLD;
};

export const transmitterAddresses = {
  [DeploymentMode.DEV]: "0x138e9840861C983DC0BB9b3e941FB7C0e9Ade320",
  [DeploymentMode.SURGE]: "0x22883bEF8302d50Ac76c6F6e048965Cd4413EBb7",
  [DeploymentMode.PROD]: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
};

export const watcherAddresses = {
  [DeploymentMode.DEV]: "0xBe6fC90D42bED21d722D5698aF2916C3a3b1393D",
  [DeploymentMode.SURGE]: "0xD7Ab0e4c8c31A91fb26552F7Ad3E91E169B86225",
  [DeploymentMode.PROD]: "0x75ddddf61b8180d3837b7d8b98c062ca442e0e14", // prod
  // [DeploymentMode.PROD]: "0x55296741c6d72a07f3965abab04737c29016f2eb", // aevo watcher
  // [DeploymentMode.PROD]: "0xA3a585c6d59CCE6aAe7035e8df48b3327cC8BE54", // sx testnet watcher 1
  // [DeploymentMode.PROD]: "0x7EFF16a34e3433182D636488bc97919b10283F37", // sx testnet watcher 2
  // [DeploymentMode.PROD]: "0x8fB53330b1AEa01f6d34faff90e0B7c2797FC3aD", // sx watcher 1
  // [DeploymentMode.PROD]: "0xE8D6b3eE50887c131D64065a97CCC786dF0bA336", // sx watcher 2
  // [DeploymentMode.PROD]: "0x3b9FF70BcdF0B459A92fce1AbE5A6A713261BA75", // sx watcher 3
  // [DeploymentMode.PROD]: "0x5Ca565e0952C44DBF1986988ba4d10A171D45FB9", // sx watcher 4
};

export const executorAddresses = {
  // [DeploymentMode.DEV]: "0x8e90345042b2720F33138CC437f8f897AC84A095", // private key
  [DeploymentMode.DEV]: "0x5ea69806b1df5dbdc6c1a78c662682ca48f9524d", // kms
  [DeploymentMode.SURGE]: "0x3051Aa7F267bF425A4e8bF766750D60391F014B4",
  [DeploymentMode.PROD]: "0x42639d8fd154b72472e149a7d5ac13fa280303d9",
};

export const overrides = (
  chain: ChainSlug | number
): {
  type?: number | undefined;
  gasLimit?: BigNumberish | undefined;
  gasPrice?: BigNumberish | undefined;
} => {
  if (chain == ChainSlug.ARBITRUM) {
    return {
      type,
      gasLimit: 200_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.ARBITRUM_SEPOLIA) {
    return {
      type: 1,
      gasLimit: 50_000_000,
      gasPrice: 1_867_830_000,
    };
  } else if (chain == ChainSlug.OPTIMISM) {
    return {
      type,
      gasLimit: 4_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.BASE) {
    return {
      type,
      gasLimit: 2_000_000,
      gasPrice: 2_000_000_000,
    };
  } else if (chain == ChainSlug.OPTIMISM_SEPOLIA) {
    return {
      type: 1,
      gasLimit: 5_000_000,
      gasPrice: 4_000_000_000,
    };
  } else if (chain == ChainSlug.BSC) {
    return {
      type,
      gasLimit: 3000000,
      gasPrice,
    };
  } else if (chain == ChainSlug.BSC_TESTNET) {
    return {
      type,
      gasLimit,
      gasPrice,
    };
  } else if (chain == ChainSlug.MAINNET) {
    return {
      // type: 1,
      gasLimit: 4_000_000,
      gasPrice: 40_000_000_000,
    };
  } else if (chain == ChainSlug.GOERLI) {
    return {
      type,
      gasLimit: 3_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.POLYGON_MAINNET) {
    return {
      type,
      gasLimit,
      gasPrice: 200_000_000_000,
    };
  } else if (chain == ChainSlug.POLYGON_MUMBAI) {
    return {
      type: 1,
      gasLimit: 3000000,
      gasPrice: 10_000_000_000,
    };
  } else if (chain == ChainSlug.SEPOLIA) {
    return {
      type,
      gasLimit: 2_000_000,
      gasPrice: 250_000_000_000,
    };
  } else if (chain == ChainSlug.AEVO_TESTNET) {
    return {
      type: 2,
      // gasLimit,
      // gasPrice,
    };
  } else if (chain == ChainSlug.AEVO) {
    return {
      type: 1,
      // gasLimit,
      gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.LYRA_TESTNET) {
    return {
      type: 2,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.LYRA) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.XAI_TESTNET) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.SX_NETWORK_TESTNET) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.MODE_TESTNET) {
    return {
      type: 1,
      // gasLimit,
      gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.SYNDR_SEPOLIA_L3) {
    return {
      type: 1,
      gasLimit: 500_000_000,
      gasPrice: 1_000_000,
    };
  } else if (chain == ChainSlug.VICTION_TESTNET) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.HOOK) {
    return {
      // type: 1,
      gasLimit: 3_000_000,
      // gasPrice: 100000000,
    };
  } else if (chain == ChainSlug.REYA_CRONOS) {
    return {
      type: 1,
      // gasLimit: 200000,
      gasPrice: 0,
    };
  } else if (chain == ChainSlug.REYA) {
    return {
      type: 1,
      // gasLimit: 20000000,
      gasPrice: 0,
    };
  } else if (chain == ChainSlug.POLYNOMIAL_TESTNET) {
    return {
      type,
      gasLimit: 4_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.KINTO) {
    return {
      type,
      gasLimit: 4_000_000,
      gasPrice,
    };
  } else if (chainConfig[chain] && chainConfig[chain].overrides) {
    return chainConfig[chain].overrides!;
  } else return { type, gasLimit, gasPrice };
};

export const relayers = [
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
  "0x660ad4B5A74130a4796B4d54BC6750Ae93C86e6c",
];
