// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";

/**
 * @title OptimisticSwitchboard
 * @notice A contract that extends the SwitchboardBase contract and implements the
 * allowPacket and fee getter functions.
 */
contract OptimisticSwitchboard is SwitchboardBase {
    /**
     * @notice Creates an OptimisticSwitchboard instance with the specified parameters.
     * @param owner_ The address of the contract owner.
     * @param socket_ The address of the socket contract.
     * @param gasPriceOracle_ The address of the gas price oracle contract.
     * @param chainSlug_ The chain slug.
     * @param timeoutInSeconds_ The timeout period in seconds.
     */
    constructor(
        address owner_,
        address socket_,
        address gasPriceOracle_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_
    )
        AccessControlExtended(owner_)
        SwitchboardBase(gasPriceOracle_, socket_, chainSlug_, timeoutInSeconds_)
    {}

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param srcChainSlug_ source chain slug
     * @param proposeTime_ time at which packet was proposed
     */
    function allowPacket(
        bytes32,
        bytes32,
        uint32 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        if (tripGlobalFuse || tripSinglePath[srcChainSlug_]) return false;
        if (block.timestamp - proposeTime_ < timeoutInSeconds) return false;
        return true;
    }

    /**
     * @dev no watcher fees needed hence returns 0
     */
    function _getMinSwitchboardFees(
        uint32,
        uint256
    ) internal pure override returns (uint256) {
        return 0;
    }
}
