export type ChainConfig = {
  chainSlug?: number;
  chainName?: string;
  timeout?: number;
  rpc?: string;
  transmitterAddress?: string;
  executorAddress?: string;
  watcherAddress?: string;
  feeUpdaterAddress?: string;
  ownerAddress?: string;
  msgValueMaxThreshold?: string | number;
  overrides?: {
    type?: number;
    gasLimit?: string | number;
    gasPrice?: string | number;
  };
};

// DON'T UPDATE AND PUSH THIS FILE
export const chainConfig: { [chain: string]: ChainConfig } = {
  "31337": {
    chainSlug: 31337,
    chainName: "hardhat",
    timeout: 7200,
    rpc: "http://127.0.0.1:8545/",
    transmitterAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    executorAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    watcherAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    feeUpdaterAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    ownerAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    msgValueMaxThreshold: 10000000000000000,
    overrides: {
      type: 1,
      gasLimit: 20000000,
      gasPrice: 1000000000000,
    },
  },
  "1": {
    overrides: {
      type: 1,
      gasLimit: 1_000_000,
      gasPrice: 40000000000, // 40 gwei
    },
  },
  "957": {
    overrides: {
      type: 1,
      gasLimit: 20000000,
      gasPrice: 100000000, // 0.1 gwei
    },
  },
  56: {
    overrides: {
      type: 1,
      gasLimit: 2_000_000,
      gasPrice: 10000000000, // 10 gwei
    },
  },
  137: {
    overrides: {
      type: 1,
      gasPrice: 10000_000_000_000, // 6000 gwei
      gasLimit: 2_000_000,
    },
  },
  42161: {
    overrides: {
      type: 2,
      gasLimit: 20_000_000,
    },
  },
  10: {
    overrides: {
      type: 2,
    },
  },
};
