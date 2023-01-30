export enum ChainId {
  GOERLI_CHAIN_ID = 5,
  KOVAN_CHAIN_ID = 42,
  POLYGON_CHAIN_ID = 137,
  MUMBAI_CHAIN_ID = 80001,
  MAINNET_CHAIN_ID = 1,
  RINKEBY_CHAIN_ID = 4,
  ROPSTEN_CHAIN_ID = 3,
  ARBITRUM_TESTNET_CHAIN_ID = 421613,
  XDAI_CHAIN_ID = 100,
  SOKOL_CHAIN_ID = 77,
  ARBITRUM_CHAIN_ID = 42161,
  FANTOM_CHAIN_ID = 250,
  OPTIMISM_CHAIN_ID = 10,
  OPTIMISM_TESTNET_CHAIN_ID = 420,
  AVAX_CHAIN_ID = 43114,
  BSC_CHAIN_ID = 56,
  AURORA_CHAIN_ID = 1313161554,
}

export enum IntegrationTypes {
  fastIntegration = "FAST",
  optimisticIntegration = "OPTIMISTIC",
  nativeIntegration = "NATIVE_BRIDGE",
}

export type Integrations = { [chainId in ChainId]?: ChainAddresses };
export type ChainAddresses = { [integration in IntegrationTypes]?: Configs };
export type Configs = {
  switchboard?: string;
  capacitor?: string;
  decapacitor?: string;
};

export interface ChainSocketAddresses {
  Counter: string;
  CapacitorFactory: string;
  ExecutionManager: string;
  GasPriceOracle: string;
  Hasher: string;
  SignatureVerifier: string;
  Socket: string;
  TransmitManager: string;
  integrations?: Integrations;
}

export type DeploymentAddresses = {
  [chainId in ChainId]?: ChainSocketAddresses;
};

export enum NativeSwitchboard {
  NON_NATIVE = 0,
  ARBITRUM_L1 = 1,
  ARBITRUM_L2 = 2,
  OPTIMISM = 3,
  POLYGON_L1 = 4,
  POLYGON_L2 = 5,
}
