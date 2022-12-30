// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISwitchboard.sol";

import "../interfaces/IOracle.sol";

import "../utils/AccessControl.sol";

contract OptimisticSwitchboard is ISwitchboard, AccessControl {
    IOracle public oracle;

    uint256 public immutable timeoutInSeconds;
    uint256 public immutable chainSlug;

    bool tripFuse;

    // TODO: change name
    // packetId => isPaused
    mapping(uint256 => bool) public isPacketPaused;
    mapping(uint256 => uint256) public executionOverhead;

    event SwitchboardTripped(bool tripFuse_);
    event ExecutionOverheadSet(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    );

    error TransferFailed();
    error FeesNotEnough();

    constructor(
        address owner_,
        address oracle_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        chainSlug = chainSlug_;
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
        if (tripFuse || isPacketPaused[packetId]) return false;
        if (block.timestamp - proposeTime < timeoutInSeconds) return false;
        return true;
    }

    function payFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug
    ) external payable override {
        uint256 dstRelativeGasPrice = oracle.getRelativeGasPrice(dstChainSlug);

        // assuming verification fees as 0
        uint256 expectedFees = _getExecutionFees(
            msgGasLimit,
            dstChainSlug,
            dstRelativeGasPrice
        );
        if (msg.value <= expectedFees) revert FeesNotEnough();
    }

    function _getExecutionFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view returns (uint256) {
        return
            (executionOverhead[dstChainSlug] + msgGasLimit) *
            dstRelativeGasPrice;
    }

    /**
     * @notice updates execution overhead
     * @param executionOverhead_ new execution overhead cost
     */
    function setExecutionOverhead(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    ) external onlyOwner {
        executionOverhead[dstChainSlug_] = executionOverhead_;
        emit ExecutionOverheadSet(dstChainSlug_, executionOverhead_);
    }

    /**
     * @notice pause/unpause execution
     * @param tripFuse_ bool indicating verification is active or not
     */
    function trip(bool tripFuse_) external onlyOwner {
        tripFuse = tripFuse_;
        emit SwitchboardTripped(tripFuse_);
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
