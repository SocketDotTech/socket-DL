export const attesterAddress: {
  [key: string]: string;
} = {
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  bsc: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x9bf84fdaa350f37ac8cb82d0042bba624b1be775",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  goerli: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  hardhat: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
};

export const executorAddress: {
  [key: string]: string;
} = {
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  bsc: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x9bf84fdaa350f37ac8cb82d0042bba624b1be775",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  goerli: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  hardhat: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
};

export const timeout: {
  [key: string]: number;
} = {
  "polygon-mainnet": 7200,
  bsc: 7200,
  "polygon-mumbai": 7200,
  "arbitrum-goerli": 7200,
  "optimism-goerli": 7200,
  goerli: 7200,
  hardhat: 7200,
};

export const contractPath: {
  [key: string]: string;
} = {
  Counter: "src/examples/Counter.sol",
  Hasher: "src/utils/Hasher.sol",
  Messenger: "src/examples/Messenger.sol",
  SignatureVerifier: "src/utils/SignatureVerifier.sol",
  SingleDeaccum: "src/deaccumulators/SingleDeaccum.sol",
  Socket: "src/Socket.sol",
  Vault: "src/vault/Vault.sol",
  // accum
  ArbitrumL1Accum:
    "src/accumulators/native-bridge/arbitrum/ArbitrumL1Accum.sol",
  ArbitrumL2Accum:
    "src/accumulators/native-bridge/arbitrum/ArbitrumL2Accum.sol",
  OptimismAccum: "src/accumulators/native-bridge/optimism/OptimismAccum.sol",
  PolygonChildAccum:
    "src/accumulators/native-bridge/polygon/PolygonChildAccum.sol",
  PolygonRootAccum:
    "src/accumulators/native-bridge/polygon/PolygonRootAccum.sol",
  SingleAccum: "src/accumulators/SingleAccum.sol",
  // notaries
  AdminNotary: "src/notaries/AdminNotary.sol",
  ArbitrumReceiver: "src/notaries/native-bridge/ArbitrumReceiver.sol",
  BondedNotary: "src/notaries/BondedNotary.sol",
  OptimismReceiver: "src/notaries/native-bridge/OptimismReceiver.sol",
  PolygonChildReceiver: "src/notaries/native-bridge/PolygonChildReceiver.sol",
  PolygonRootReceiver: "src/notaries/native-bridge/PolygonRootReceiver.sol",
  // verifiers
  NativeBridgeVerifier: "src/verifiers/NativeBridgeVerifier.sol",
  Verifier: "src/verifiers/Verifier.sol",
};

export const fastIntegration = "FAST";
export const slowIntegration = "SLOW";
export const arbNativeBridgeIntegration = "ARBITRUM_NATIVE_BRIDGE_CONFIG";
export const optimismNativeBridgeIntegration = "OPTIMISM_NATIVE_BRIDGE_CONFIG";
export const polygonNativeBridgeIntegration = "POLYGON_NATIVE_BRIDGE_CONFIG";

export const contractNames = (
  integrationType: string,
  srcChain: string,
  dstChain: string
) => {
  let contracts = {
    "arbitrum-goerli": {
      goerli: {
        integrationType: arbNativeBridgeIntegration,
        accum: "ArbitrumL2Accum",
        verifier: "NativeBridgeVerifier",
        notary: "ArbitrumReceiver",
      },
    },
    "arbitrum-mainnet": {
      mainnet: {
        integrationType: arbNativeBridgeIntegration,
        accum: "ArbitrumL2Accum",
        verifier: "NativeBridgeVerifier",
        notary: "ArbitrumReceiver",
      },
    },
    "optimism-mainnet": {
      mainnet: {
        integrationType: optimismNativeBridgeIntegration,
        accum: "OptimismAccum",
        verifier: "NativeBridgeVerifier",
        notary: "OptimismReceiver",
      },
    },
    "optimism-goerli": {
      goerli: {
        integrationType: optimismNativeBridgeIntegration,
        accum: "OptimismAccum",
        verifier: "NativeBridgeVerifier",
        notary: "OptimismReceiver",
      },
    },
    "polygon-mainnet": {
      mainnet: {
        integrationType: polygonNativeBridgeIntegration,
        accum: "PolygonChildAccum",
        verifier: "NativeBridgeVerifier",
        notary: "PolygonChildReceiver",
      },
    },
    "polygon-mumbai": {
      goerli: {
        integrationType: polygonNativeBridgeIntegration,
        accum: "PolygonChildAccum",
        verifier: "NativeBridgeVerifier",
        notary: "PolygonChildReceiver",
      },
    },
    goerli: {
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
        notary: "PolygonRootReceiver",
      },
    },
    mainnet: {
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
        notary: "PolygonRootReceiver",
      },
    },
    default: {
      integrationType,
      accum: "SingleAccum",
      verifier: "Verifier",
      notary: "AdminNotary",
    },
  };

  if (
    integrationType === fastIntegration ||
    integrationType === slowIntegration
  )
    return contracts["default"];
  if (!contracts[srcChain] || !contracts[srcChain][dstChain])
    return contracts["default"];

  return contracts[srcChain][dstChain];
};
