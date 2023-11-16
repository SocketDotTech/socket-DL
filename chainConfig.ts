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
  56: {
    overrides: {
      type: 1,
      gasLimit: 20000000,
      gasPrice: 1000000000000,
    },
  },
};
