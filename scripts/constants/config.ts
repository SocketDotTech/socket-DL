import { IntegrationTypes, NativeSwitchboard } from "../../src/types";

export const transmitterAddress: {
  [key: string]: string;
} = {
  "bsc-testnet": "0xd37674fb952e0095d352f66a5796f39f18cd631a",
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  bsc: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x9bf84fdaa350f37ac8cb82d0042bba624b1be775",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  goerli: "0x3c16684415d0fd630e7f6866021db43ca96479c4",
  hardhat: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  arbitrum: "0x95e655674C6889F80fa024ebA86cdE29D69028A6",
  optimism: "0xfceE44a59d4cdF48F58956aa4F1b580D6469a312",
  mainnet: "0x6956063c490fa746c9801ccc41baba8a8b678068",
};

export const watcherAddress: {
  [key: string]: string;
} = {
  "bsc-testnet": "0xd37674fb952e0095d352f66a5796f39f18cd631a",
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  bsc: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x9bf84fdaa350f37ac8cb82d0042bba624b1be775",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  goerli: "0x3c16684415d0fd630e7f6866021db43ca96479c4",
  hardhat: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  arbitrum: "0x95e655674C6889F80fa024ebA86cdE29D69028A6",
  optimism: "0xfceE44a59d4cdF48F58956aa4F1b580D6469a312",
  mainnet: "0x6956063c490fa746c9801ccc41baba8a8b678068",
};

export const executorAddress: {
  [key: string]: string;
} = {
  "bsc-testnet": "0xd37674fb952e0095d352f66a5796f39f18cd631a",
  "polygon-mainnet": "0x8eCEfE7dd4F86D4a96Ff89eBB34C3c6F7871c4c7",
  bsc: "0x5FB308DdF9f2df0f2b9916C4b7Ba8915B3a5A565",
  "polygon-mumbai": "0x4b53d8d45fe48e0039db40bc21f0a3fc70d0a922",
  "arbitrum-goerli": "0x9bf84fdaa350f37ac8cb82d0042bba624b1be775",
  "optimism-goerli": "0x222914bfac6c6f6f10fa1bd38bd5f1d6851bd9ff",
  goerli: "0x3c16684415d0fd630e7f6866021db43ca96479c4",
  hardhat: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  arbitrum: "0x95e655674C6889F80fa024ebA86cdE29D69028A6",
  optimism: "0xfceE44a59d4cdF48F58956aa4F1b580D6469a312",
  mainnet: "0x6956063c490fa746c9801ccc41baba8a8b678068",
};

export const timeout: {
  [key: string]: number;
} = {
  "bsc-testnet": 7200,
  "polygon-mainnet": 7200,
  bsc: 7200,
  "polygon-mumbai": 7200,
  "arbitrum-goerli": 7200,
  "optimism-goerli": 7200,
  goerli: 7200,
  hardhat: 7200,
  arbitrum: 7200,
  optimism: 7200,
  mainnet: 7200,
};

export const sealGasLimit: {
  [key: string]: number;
} = {
  "bsc-testnet": 300000,
  "polygon-mainnet": 300000,
  bsc: 300000,
  "polygon-mumbai": 300000,
  "arbitrum-goerli": 300000,
  "optimism-goerli": 300000,
  goerli: 300000,
  hardhat: 300000,
  arbitrum: 300000,
  optimism: 300000,
  mainnet: 300000,
};

export const proposeGasLimit: {
  [key: string]: number;
} = {
  "bsc-testnet": 300000,
  "polygon-mainnet": 300000,
  bsc: 300000,
  "polygon-mumbai": 300000,
  "arbitrum-goerli": 300000,
  "optimism-goerli": 300000,
  goerli: 300000,
  hardhat: 300000,
  arbitrum: 300000,
  optimism: 300000,
  mainnet: 300000,
};

export const EXECUTOR_ROLE =
  "0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767";

export const switchboards = {
  "arbitrum-goerli": {
    goerli: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  arbitrum: {
    mainnet: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  optimism: {
    mainnet: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  "optimism-goerli": {
    goerli: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  "polygon-mainnet": {
    mainnet: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  "polygon-mumbai": {
    goerli: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  goerli: {
    "arbitrum-goerli": {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    "optimism-goerli": {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    "polygon-mumbai": {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
  mainnet: {
    arbitrum: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    optimism: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    "polygon-mainnet": {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
};
