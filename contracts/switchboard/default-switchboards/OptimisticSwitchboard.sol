// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";

contract OptimisticSwitchboard is SwitchboardBase {
    uint256 public immutable timeoutInSeconds;

    error WatcherFound();
    error WatcherNotFound();

    constructor(
        address owner_,
        address oracle_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        oracle__ = IOracle(oracle_);
        timeoutInSeconds = timeoutInSeconds_;
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packet id
     * @param proposeTime_ time at which packet was proposed
     */
    function allowPacket(
        bytes32,
        uint256 packetId_,
        uint256 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        if (tripGlobalFuse || tripSinglePath[srcChainSlug_]) return false;
        if (block.timestamp - proposeTime_ < timeoutInSeconds) return false;
        return true;
    }

    /**
     * @notice pause execution
     */
    function tripGlobal(
        uint256 srcChainSlug_
    ) external onlyRole(_watcherRole(srcChainSlug_)) {
        tripGlobalFuse = true;
        emit SwitchboardTripped(true);
    }

    /**
     * @notice pause/unpause execution
     */
    function tripGlobal(bool trip_) external onlyOwner {
        tripGlobalFuse = trip_;
        emit SwitchboardTripped(trip_);
    }

    /**
     * @notice adds an watcher for `remoteChainSlug_` chain
     * @param remoteChainSlug_ remote chain slug
     * @param watcher_ watcher address
     */
    function grantWatcherRole(
        uint256 remoteChainSlug_,
        address watcher_
    ) external onlyOwner {
        if (_hasRole(_watcherRole(remoteChainSlug_), watcher_))
            revert WatcherFound();

        _grantRole(_watcherRole(remoteChainSlug_), watcher_);
    }

    /**
     * @notice removes an watcher from `remoteChainSlug_` chain list
     * @param remoteChainSlug_ remote chain slug
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(
        uint256 remoteChainSlug_,
        address watcher_
    ) external onlyOwner {
        if (!_hasRole(_watcherRole(remoteChainSlug_), watcher_))
            revert WatcherNotFound();

        _revokeRole(_watcherRole(remoteChainSlug_), watcher_);
    }
}
