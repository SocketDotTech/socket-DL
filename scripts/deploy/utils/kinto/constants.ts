export const KINTO_DATA = {
  contracts: {
    kintoID: {
      // address: "0xf369f78E3A0492CC4e96a90dae0728A38498e9c7", // mainnet
      address: "0xd7Fa9143481d9c48DF79Bb042A6A7a51C99112B6",
      abi: [
        "function nonces(address) view returns (uint256)",
        "function domainSeparator() view returns (bytes32)",
      ],
    },
    kintoWallet: {
      // address: "0x2e2B1c42E38f5af81771e65D87729E57ABD1337a", // Socket's kinto wallet
      address: "0x41d63E71941Cd489d7BbE297d79A6B0827544F7A",
      abi: [
        "function getNonce() view returns (uint256)",
        "function whitelistApp(address[] calldata apps, bool[] calldata flags)",
        "function execute(address dest, uint256 value, bytes calldata func)",
      ],
    },
    factory: {
      // address: "0x8a4720488CA32f1223ccFE5A087e250fE3BC5D75", // mainnet
      address: "0xB6816E20AfC8412b7D6eD491F0c41317315c29D3",
      abi: [
        "function deployContract(address contractOwner, uint256 amount, bytes memory bytecode, bytes32 salt) returns (address)",
      ],
    },
    entryPoint: {
      // address: "0x2843C269D2a64eCfA63548E8B3Fc0FD23B7F70cb", // mainnet
      address: "0xEeb65A06722E6B7141114980Fff7d86CCB14F435",
      abi: [
        "function handleOps(tuple(address sender, uint256 nonce, bytes initCode, bytes callData, uint256 callGasLimit, uint256 verificationGasLimit, uint256 preVerificationGas, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, bytes paymasterAndData, bytes signature)[] ops, address beneficiary)",
      ],
    },
    paymaster: {
      // address: "0x1842a4EFf3eFd24c50B63c3CF89cECEe245Fc2bd", // mainnet
      address: "0x29C157fb553D9EAD78e5084F74E02F2ACEbE6770",
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
