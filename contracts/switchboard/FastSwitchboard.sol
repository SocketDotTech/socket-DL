// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISwitchboard.sol";
import "../interfaces/IOracle.sol";

import "../utils/AccessControl.sol";

contract FastSwitchboard is ISwitchboard, AccessControl {
    IOracle public oracle;

    mapping(uint256 => uint256) public executionOverhead;

    uint256 public immutable chainSlug;
    uint256 public timeoutInSeconds;

    bool public tripGlobalFuse;
    // packetId => isPaused
    mapping(uint256 => bool) public tripSingleFuse;

    // dst chain slug => total watchers registered
    mapping(uint256 => uint256) public totalWatchers;

    // dst chain slug => attest gas limit
    mapping(uint256 => uint256) public attestGasLimit;

    // attester => packetId => is attested
    mapping(address => mapping(uint256 => bool)) public isAttested;

    // packetId => total attestations
    mapping(uint256 => uint256) public attestations;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event PacketTripped(uint256 packetId_, bool tripSingleFuse_);
    event PacketAttested(uint256 packetId, address attester);
    event AttestGasLimitSet(uint256 dstChainSlug_, uint256 attestGasLimit_);
    event ExecutionOverheadSet(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    );

    error TransferFailed();
    error FeesNotEnough();
    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();

    constructor(
        address owner_,
        address oracle_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        chainSlug = chainSlug_;
        oracle = IOracle(oracle_);

        timeoutInSeconds = timeoutInSeconds_;
    }

    function attest(
        uint256 packetId,
        uint256 srcChainSlug
    ) external onlyRole(_watcherRole(srcChainSlug)) {
        if (isAttested[msg.sender][packetId]) revert AlreadyAttested();

        isAttested[msg.sender][packetId] = true;
        attestations[packetId]++;

        emit PacketAttested(packetId, msg.sender);
    }

    // todo: switchboard might need src chain slug and packet id while verifying details here?
    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId packetId
     * @param proposeTime time at which packet was proposed
     */
    function allowPacket(
        bytes32,
        uint256 packetId,
        uint256 srcChainSlug,
        uint256 proposeTime
    ) external view override returns (bool) {
        if (tripGlobalFuse || tripSingleFuse[packetId]) return false;

        // to handle the situation if a watcher is removed after it attested the packet
        if (attestations[packetId] >= totalWatchers[srcChainSlug]) return true;
        if (block.timestamp - proposeTime >= timeoutInSeconds) return true;

        return false;
    }

    function payFees(
        uint256 msgGasLimit,
        uint256 dstChainSlug
    ) external payable override {
        uint256 dstRelativeGasPrice = oracle.relativeGasPrice(dstChainSlug);

        uint256 minExecutionFees = _getExecutionFees(
            msgGasLimit,
            dstChainSlug,
            dstRelativeGasPrice
        );
        uint256 minVerificationFees = _getVerificationFees(
            dstChainSlug,
            dstRelativeGasPrice
        );

        uint256 expectedFees = minExecutionFees + minVerificationFees;
        if (msg.value < expectedFees) revert FeesNotEnough();
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

    function _getVerificationFees(
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view returns (uint256) {
        // todo: are the watchers going to be same on all chains for particular chain slug?
        return
            totalWatchers[dstChainSlug] *
            attestGasLimit[dstChainSlug] *
            dstRelativeGasPrice;
    }

    /**
     * @notice updates attest gas limit for given chain slug
     * @param dstChainSlug_ destination chain
     * @param attestGasLimit_ average gas limit needed for attest function call
     */
    function setAttestGasLimit(
        uint256 dstChainSlug_,
        uint256 attestGasLimit_
    ) external onlyOwner {
        attestGasLimit[dstChainSlug_] = attestGasLimit_;
        emit AttestGasLimitSet(dstChainSlug_, attestGasLimit_);
    }

    function setExecutionOverhead(
        uint256 dstChainSlug_,
        uint256 executionOverhead_
    ) external onlyOwner {
        executionOverhead[dstChainSlug_] = executionOverhead_;
        emit ExecutionOverheadSet(dstChainSlug_, executionOverhead_);
    }

    /**
     * @notice pause/unpause execution
     * @param tripSingleFuse_ bool indicating verification is active or not
     */
    function tripSingle(
        uint256 packetId_,
        uint256 srcChainSlug_,
        bool tripSingleFuse_
    ) external onlyRole(_watcherRole(srcChainSlug_)) {
        tripSingleFuse[packetId_] = tripSingleFuse_;
        emit PacketTripped(packetId_, tripSingleFuse_);
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
     * @notice adds a watcher for `srcChainSlug_` chain
     * @param watcher_ watcher address
     */
    function grantWatcherRole(
        uint256 srcChainSlug_,
        address watcher_
    ) external onlyOwner {
        if (_hasRole(_watcherRole(srcChainSlug_), watcher_))
            revert WatcherFound();

        _grantRole(_watcherRole(srcChainSlug_), watcher_);
        totalWatchers[srcChainSlug_]++;
    }

    /**
     * @notice removes a watcher from `srcChainSlug_` chain list
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(
        uint256 srcChainSlug_,
        address watcher_
    ) external onlyOwner {
        if (!_hasRole(_watcherRole(srcChainSlug_), watcher_))
            revert WatcherNotFound();

        _revokeRole(_watcherRole(srcChainSlug_), watcher_);
        totalWatchers[srcChainSlug_]--;
    }

    function _watcherRole(uint256 chainSlug_) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }
}
