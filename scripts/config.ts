export const signerAddress: {
  [key: number]: string
} = {
  80001: "0xbb244dd59a34c9ca5c7d0cb9d1c270188b9f45bc",
  421611: "0x89c59d70d0d2671ca1a36871f6c4c61985677d7b",
  420: "0x89c59d70d0d2671ca1a36871f6c4c61985677d7b",
  31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  31338: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const executorAddress: {
  [key: number]: string
} = {
  80001: "0xbb244dd59a34c9ca5c7d0cb9d1c270188b9f45bc",
  421611: "0x89c59d70d0d2671ca1a36871f6c4c61985677d7b",
  420: "0x89c59d70d0d2671ca1a36871f6c4c61985677d7b",
  31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  31338: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const timeout: {
  [key: number]: number
} = {
  80001: 7200,
  421611: 7200,
  420: 7200,
  31337: 7200,
  31338: 7200
}

export const slowPathWaitTime: {
  [key: number]: number
} = {
  80001: 3600,
  421611: 3600,
  420: 3600,
  31337: 3600,
  31338: 3600
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

export const isFast = true;
export const destChainId = 421611;
