// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 destChainId;
        address signer;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[31337] = getAnvilEthConfig();
        chainIdToNetworkConfig[31338] = getAnvilEthConfig();

        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getAnvilEthConfig()
        internal
        view
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        anvilNetworkConfig = NetworkConfig({
            destChainId: block.chainid == 31337 ? 31338 : 31337,
            signer: address(1)
        });
    }
}
