// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISwitchboard.sol";
import "../utils/AccessControl.sol";

contract OptimisticSwitchboard is ISwitchboard, AccessControl {
    uint256 public immutable timeoutInSeconds;
    uint256 public immutable chainSlug;

    bool public tripGlobalFuse;
    // packetId => isPaused
    mapping(uint256 => bool) public tripSingleFuse;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event PacketTripped(uint256 packetId_, bool tripSingleFuse_);

    error TransferFailed();
    error FeesNotEnough();
    error WatcherNotFound();

    constructor(
        address owner_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        chainSlug = chainSlug_;

        // TODO: restrict the timeout durations to a few select options
        timeoutInSeconds = timeoutInSeconds_;
    }

    function payFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug
    ) external payable override {
        // TODO: updated with issue #45
        uint256 expectedFees = 0;
        if (msg.value != expectedFees) revert FeesNotEnough();
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
    function tripGlobal(
        uint256 srcChainSlug_,
        bool tripGlobalFuse_
    ) external onlyRole(_watcherRole(srcChainSlug_)) {
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
    ) external onlyRole(_watcherRole(srcChainSlug_)) {
        tripSingleFuse[packetId_] = tripSingleFuse_;
        emit PacketTripped(packetId_, tripSingleFuse_);
    }

    // TODO: to support fee distribution
    /**
     * @notice transfers the fees collected to `account_`
     * @param account_ address to transfer ETH
     */
    function withdrawFees(address account_) external onlyOwner {
        require(account_ != address(0));
        (bool success, ) = account_.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
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
