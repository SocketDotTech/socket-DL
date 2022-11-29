import { IntegrationTypes } from "../../src/types";

export const attesterAddress: {
  [key: string]: string;
} = {
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  bsc: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x9bf84fdaa350f37ac8cb82d0042bba624b1be775",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  goerli: "0x3c16684415d0fd630e7f6866021db43ca96479c4",
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
  goerli: "0x3c16684415d0fd630e7f6866021db43ca96479c4",
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
  Counter: "contracts/examples/Counter.sol",
  Hasher: "contracts/utils/Hasher.sol",
  Messenger: "contracts/examples/Messenger.sol",
  SignatureVerifier: "contracts/utils/SignatureVerifier.sol",
  SingleDeaccum: "contracts/deaccumulators/SingleDeaccum.sol",
  Socket: "contracts/Socket.sol",
  Vault: "contracts/vault/Vault.sol",
  SingleAccum: "contracts/accumulators/SingleAccum.sol",
  // notaries
  AdminNotary: "contracts/notaries/AdminNotary.sol",
  ArbitrumNotary: "contracts/notaries/native-bridge/ArbitrumNotary.sol",
  BondedNotary: "contracts/notaries/BondedNotary.sol",
  OptimismNotary: "contracts/notaries/native-bridge/OptimismNotary.sol",
  PolygonL2Notary: "contracts/notaries/native-bridge/PolygonL2Notary.sol",
  PolygonL1Notary: "contracts/notaries/native-bridge/PolygonL1Notary.sol",
  // verifiers
  NativeBridgeVerifier: "contracts/verifiers/NativeBridgeVerifier.sol",
  Verifier: "contracts/verifiers/Verifier.sol",
};

const notaries = {
  "arbitrum-goerli": {
    goerli: {
      notary: "ArbitrumNotary",
    },
  },
  "arbitrum-mainnet": {
    mainnet: {
      notary: "ArbitrumNotary",
    },
  },
  "optimism-mainnet": {
    mainnet: {
      notary: "OptimismNotary",
    },
  },
  "optimism-goerli": {
    goerli: {
      notary: "OptimismNotary",
    },
  },
  "polygon-mainnet": {
    mainnet: {
      notary: "PolygonL2Notary",
    },
  },
  "polygon-mumbai": {
    goerli: {
      notary: "PolygonL2Notary",
    },
  },
  goerli: {
    "arbitrum-goerli": {
      notary: "ArbitrumNotary",
    },
    "optimism-goerli": {
      notary: "OptimismNotary",
    },
    "polygon-mumbai": {
      notary: "PolygonL1Notary",
    },
  },
  mainnet: {
    "arbitrum-mainnet": {
      notary: "ArbitrumNotary",
    },
    "optimism-mainnet": {
      notary: "OptimismNotary",
    },
    "polygon-mainnet": {
      notary: "PolygonL1Notary",
    },
  }
};

export const contractNames = (
  integrationType: string,
  srcChain: string,
  dstChain: string
) => {
  if (
    integrationType === IntegrationTypes.fastIntegration ||
    integrationType === IntegrationTypes.slowIntegration ||
    !notaries[srcChain]?.[dstChain]?.["notary"]
  )
    return {
      integrationType,
      verifier: "Verifier",
      notary: "AdminNotary"
    };

  return {
    integrationType: IntegrationTypes.nativeIntegration,
    verifier: "NativeBridgeVerifier",
    notary: notaries[srcChain][dstChain]["notary"],
  };
};
