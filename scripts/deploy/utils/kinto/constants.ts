export const KINTO_DATA = {
  contracts: {
    kintoID: {
      address: "0xf369f78E3A0492CC4e96a90dae0728A38498e9c7",
      abi: [
        "function nonces(address) view returns (uint256)",
        "function domainSeparator() view returns (bytes32)",
      ],
    },
    kintoWallet: {
      abi: [
        "function getNonce() view returns (uint256)",
        "function whitelistApp(address[] calldata apps, bool[] calldata flags)",
        "function execute(address dest, uint256 value, bytes calldata func)",
      ],
    },
    factory: {
      address: "0x8a4720488CA32f1223ccFE5A087e250fE3BC5D75",
      abi: [
        "function deployContract(address contractOwner, uint256 amount, bytes memory bytecode, bytes32 salt) returns (address)",
      ],
    },
    entryPoint: {
      address: "0x2843C269D2a64eCfA63548E8B3Fc0FD23B7F70cb",
      abi: [
        "function handleOps(tuple(address sender, uint256 nonce, bytes initCode, bytes callData, uint256 callGasLimit, uint256 verificationGasLimit, uint256 preVerificationGas, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, bytes paymasterAndData, bytes signature)[] ops, address beneficiary)",
      ],
    },
    paymaster: {
      address: "0x1842a4EFf3eFd24c50B63c3CF89cECEe245Fc2bd",
      abi: ["function balances(address) view returns (uint256)"],
    },
    // custom contract to deploy contracts inheriting the 2-step Ownable.sol
    deployer: {
      address: "0x", // find it on prod_addresses.json
      abi: [
        "function deploy(address owner, bytes calldata bytecode, bytes32 salt) public returns (address)",
      ],
    },
  },
  gasParams: {
    callGasLimit: 4000000,
    verificationGasLimit: 210000,
    preVerificationGas: 21000,
  },
};
