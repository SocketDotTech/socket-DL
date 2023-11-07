export type ChainConfig = {
  chainSlug: number;
  chainName: string;
  timeout: number;
  rpc: string;
  transmitterAddress: string;
  executorAddress: string;
  watcherAddress: string;
  feeUpdaterAddress: string;
  ownerAddress: string;
  msgValueMaxThreshold?: string | number;
  overrides?: {
    type?: number;
    gasLimit?: string | number;
    gasPrice?: string | number;
  };
};

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
  "647": {
    chainSlug: 647,
    chainName: "sxn_testnet",
    timeout: 7200,
    rpc: "https://rpc.toronto.sx.technology/",
    transmitterAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    executorAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    watcherAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    feeUpdaterAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
    ownerAddress: "0xdE7f7a699F8504641eceF544B0fbc0740C37E69B",
  },
  "686669576": {
    chainSlug: 686669576,
    chainName: "cdk_testnet",
    timeout: 7200,
    rpc: "https://sn2-stavanger-rpc.eu-north-2.gateway.fm",
    transmitterAddress: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
    executorAddress: "0x42639d8fd154b72472e149a7d5ac13fa280303d9",
    watcherAddress: "0x75ddddf61b8180d3837b7d8b98c062ca442e0e14",
    feeUpdaterAddress: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
    ownerAddress: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
    overrides: {
      type: 0,
    },
  },
  "421614": {
    chainSlug: 421614,
    chainName: "arbitrum_sepolia",
    timeout: 7200,
    rpc: "https://broken-tame-morning.arbitrum-sepolia.quiknode.pro/317a841dd4460bed62d6b16b6b6e9c4fe0f77e39/",
    transmitterAddress: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
    executorAddress: "0x42639d8fd154b72472e149a7d5ac13fa280303d9",
    watcherAddress: "0x75ddddf61b8180d3837b7d8b98c062ca442e0e14",
    feeUpdaterAddress: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
    ownerAddress: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  },
  "11155420": {
    chainSlug: 11155420,
    chainName: "optimism_sepolia",
    timeout: 7200,
    rpc: "https://sepolia.optimism.io",
    transmitterAddress: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
    executorAddress: "0x42639d8fd154b72472e149a7d5ac13fa280303d9",
    watcherAddress: "0x75ddddf61b8180d3837b7d8b98c062ca442e0e14",
    feeUpdaterAddress: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
    ownerAddress: "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa",
  },
};
