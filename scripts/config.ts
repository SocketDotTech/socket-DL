export const attesterAddress: {
  [key: number]: string
} = {
  10: "0xfceE44a59d4cdF48F58956aa4F1b580D6469a312",
  42161: "0x95e655674C6889F80fa024ebA86cdE29D69028A6",
  137: "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  56: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  80001: "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  421613: "0x39ea4452f2fb4861b28cf1db42a089afbcc1dbd5",
  420: "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  31338: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const executorAddress: {
  [key: number]: string
} = {
  10: "0xfceE44a59d4cdF48F58956aa4F1b580D6469a312",
  42161: "0x95e655674C6889F80fa024ebA86cdE29D69028A6",
  137: "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  56: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  80001: "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  421613: "0x39ea4452f2fb4861b28cf1db42a089afbcc1dbd5",
  420: "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  31338: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const timeout: {
  [key: number]: number
} = {
  10: 7200,
  42161: 7200,
  80001: 7200,
  421613: 7200,
  420: 7200,
  31337: 7200,
  31338: 7200,
  137: 7200,
  56: 7200
}

export const contractPath: {
  [key: string]: string
} = {
  "BaseAccum": "src/accumulators/BaseAccum.sol",
  "SingleAccum": "src/accumulators/SingleAccum.sol",
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

export const isFast = true;
export const remoteChainId = 80001;
export const totalRemoteChains = [56, 137, 42161];