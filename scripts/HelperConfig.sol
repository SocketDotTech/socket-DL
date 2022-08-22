// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 destChainId;
        address signer;
        address pauser;
        bool isSequential;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[31337] = getAnvilEthConfig();
        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getAnvilEthConfig()
        internal
        pure
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        anvilNetworkConfig = NetworkConfig({
            destChainId: 1,
            signer: address(1),
            pauser: address(2),
            isSequential: false
        });
    }
}
