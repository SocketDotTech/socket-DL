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
export type IntegrationTypeAddresses = { string: ChainAddresses }

export interface ChainSocketAddresses {
  Counter: string,
  Hasher: string,
  AdminNotary: string,
  SignatureVerifier: string,
  Socket: string,
  Vault: string,
  Verifier: string,
  SingleAccum: IntegrationTypeAddresses,
  SingleDeaccum: IntegrationTypeAddresses
}

export type DeploymentAddresses = { [chainId in ChainId]?: ChainSocketAddresses }