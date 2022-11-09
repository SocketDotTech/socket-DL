export const attesterAddress: {
  [key: string]: string
} = {
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  "bsc": "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  "goerli": "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  "hardhat": "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const executorAddress: {
  [key: string]: string
} = {
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  "bsc": "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  "goerli": "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  "hardhat": "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const timeout: {
  [key: string]: number
} = {
  "polygon-mainnet": 7200,
  "bsc": 7200,
  "polygon-mumbai": 7200,
  "arbitrum-goerli": 7200,
  "optimism-goerli": 7200,
  "goerli": 7200,
  "hardhat": 7200
}

export const contractPath: {
  [key: string]: string
} = {
  "BaseAccum": "src/accumulators/BaseAccum.sol",
  "SingleAccum": "src/accumulators/SingleAccum.sol",
  "ArbitrumL1Accum": "src/accumulators/ArbitrumL1Accum.sol",
  "ArbitrumL2Accum": "src/accumulators/ArbitrumL2Accum.sol",
  "SingleDeaccum": "src/deaccumulators/SingleDeaccum.sol",
  "Counter": "src/examples/Counter.sol",
  "Messenger": "src/examples/Messenger.sol",
  "Hasher": "src/utils/Hasher.sol",
  "SignatureVerifier": "src/utils/SignatureVerifier.sol",
  "Vault": "src/vault/Vault.sol",
  "Verifier": "src/verifiers/Verifier.sol",
  "AdminNotary": "src/notaries/AdminNotary.sol",
  "BondedNotary": "src/notaries/BondedNotary.sol",
  "Socket": "src/Socket.sol",
}

export const fastIntegration = "FAST";
export const slowIntegration = "SLOW";
export const arbNativeBridgeIntegration = "ARBITRUM_NATIVE_BRIDGE";
