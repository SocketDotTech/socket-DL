// TODO: Import from ll-core?
export enum ChainId {
  CHAIN_ID_56 = 56,
  CHAIN_ID_137 = 137,
  CHAIN_ID_420 = 420,
  CHAIN_ID_80001 = 80001,
  CHAIN_ID_421611 = 421611,
  CHAIN_ID_421613 = 421613,
} 

export type ChainAddresses = { [chainId in ChainId]?: string }

export interface ChainSocketAddresses {
  counter: string,
  hasher: string,
  notary: string,
  signatureVerifier: string,
  socket: string,
  vault: string,
  verifier: string,
  fastAccum: ChainAddresses,
  slowAccum: ChainAddresses,
  deaccum: ChainAddresses
}

export type DeploymentAddresses = {[chainId in ChainId]?: ChainSocketAddresses}