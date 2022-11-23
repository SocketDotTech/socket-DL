export enum ChainId {
  GOERLI_CHAIN_ID = 5,
  KOVAN_CHAIN_ID = 42,
  POLYGON_CHAIN_ID = 137,
  MUMBAI_CHAIN_ID = 80001,
  MAINNET_CHAIN_ID = 1,
  RINKEBY_CHAIN_ID = 4,
  ROPSTEN_CHAIN_ID = 3,
  ARBITRUM_TESTNET_CHAIN_ID = 421611,
  XDAI_CHAIN_ID = 100,
  SOKOL_CHAIN_ID = 77,
  ARBITRUM_CHAIN_ID = 42161,
  FANTOM_CHAIN_ID = 250,
  OPTIMISM_CHAIN_ID = 10,
  AVAX_CHAIN_ID = 43114,
  BSC_CHAIN_ID = 56,
  AURORA_CHAIN_ID = 1313161554,
}

export type ChainAddresses = { [chainId in ChainId]?: string };

export interface ChainSocketAddresses {
  counter: string;
  hasher: string;
  notary: string;
  signatureVerifier: string;
  socket: string;
  vault: string;
  verifier: string;
  fastAccum: ChainAddresses;
  slowAccum: ChainAddresses;
  deaccum: ChainAddresses;
}

export type DeploymentAddresses = {
  [chainId in ChainId]?: ChainSocketAddresses;
};
