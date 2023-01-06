// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";

contract OptimisticSwitchboard is SwitchboardBase {
    uint256 public immutable timeoutInSeconds;

    // packetId => isPaused
    mapping(uint256 => bool) public tripSingleFuse;

    event PacketTripped(uint256 packetId_, bool tripSingleFuse_);
    error WatcherNotFound();

    constructor(
        address owner_,
        address oracle_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        oracle = IOracle(oracle_);

        // TODO: restrict the timeout durations to a few select options
        timeoutInSeconds = timeoutInSeconds_;
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId packet id
     * @param proposeTime time at which packet was proposed
     */
    function allowPacket(
        bytes32,
        uint256 packetId,
        uint256,
        uint256 proposeTime
    ) external view override returns (bool) {
        if (tripGlobalFuse || tripSingleFuse[packetId]) return false;
        if (block.timestamp - proposeTime < timeoutInSeconds) return false;
        return true;
    }

    /**
     * @notice pause/unpause execution
     * @param tripGlobalFuse_ bool indicating verification is active or not
     */
    function tripGlobal(uint256 srcChainSlug_, bool tripGlobalFuse_) external {
        if (!_hasRole(_watcherRole(srcChainSlug_), msg.sender))
            revert WatcherNotFound();

        tripGlobalFuse = tripGlobalFuse_;
        emit SwitchboardTripped(tripGlobalFuse_);
    }

    /**
     * @notice pause/unpause a packet
     * @param tripSingleFuse_ bool indicating a packet is verified or not
     */
    function tripSingle(
        uint256 packetId_,
        uint256 srcChainSlug_,
        bool tripSingleFuse_
    ) external {
        if (!_hasRole(_watcherRole(srcChainSlug_), msg.sender))
            revert WatcherNotFound();

        tripSingleFuse[packetId_] = tripSingleFuse_;
        emit PacketTripped(packetId_, tripSingleFuse_);
    }

    function _getExecutionFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
        return
            (executionOverhead[dstChainSlug] + msgGasLimit) *
            dstRelativeGasPrice;
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
        _revokeRole(_watcherRole(remoteChainSlug_), watcher_);
    }

    function _watcherRole(uint256 chainSlug_) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }
}
