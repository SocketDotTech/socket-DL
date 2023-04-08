// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";

contract OptimisticSwitchboard is SwitchboardBase {
    constructor(
        address owner_,
        address gasPriceOracle_,
        uint256 chainSlug_,
        uint256 timeoutInSeconds_
    )
        AccessControlExtended(owner_)
        SwitchboardBase(gasPriceOracle_, chainSlug_, timeoutInSeconds_)
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

    function _getMinSwitchboardFees(
        uint256,
        uint256
    ) internal pure override returns (uint256) {
        return 0;
    }
}
