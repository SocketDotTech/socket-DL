export const signerAddress: {
  [key: number]: string
} = {
  80001: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  421613: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  420: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  31338: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const executorAddress: {
  [key: number]: string
} = {
  80001: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  421613: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  420: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  31337: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  31338: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
}

export const timeout: {
  [key: number]: number
} = {
  80001: 0,
  421613: 0,
  420: 0,
  31337: 0,
  31338: 0
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

export const srcChainId = 31337;
export const destChainId = 31337;