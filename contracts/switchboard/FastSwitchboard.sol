// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ISocket.sol";
import "./SwitchboardBase.sol";

contract FastSwitchboard is SwitchboardBase {
    ISocket public socket;
    uint256 public timeoutInSeconds;

    // dst chain slug => total watchers registered
    mapping(uint256 => uint256) public totalWatchers;

    // dst chain slug => attest gas limit
    mapping(uint256 => uint256) public attestGasLimit;

    // attester => packetId => is attested
    mapping(address => mapping(uint256 => bool)) public isAttested;

    // packetId => total attestations
    mapping(uint256 => uint256) public attestations;

    event SocketSet(address newSocket_);
    event PacketAttested(uint256 packetId, address attester);
    event AttestGasLimitSet(uint256 dstChainSlug_, uint256 attestGasLimit_);

    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();

    constructor(
        address owner_,
        address socket_,
        address oracle_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) SwitchboardBase(chainSlug_) {
        oracle = IOracle(oracle_);

        socket = ISocket(socket_);
        timeoutInSeconds = timeoutInSeconds_;
    }

    function attest(uint256 packetId, uint256 srcChainSlug) external {
        if (isAttested[msg.sender][packetId]) revert AlreadyAttested();
        if (!_hasRole(_watcherRole(srcChainSlug), msg.sender))
            revert WatcherNotFound();

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
        if (tripGlobalFuse) return false;

        // to handle the situation if a watcher is removed after it attested the packet
        if (attestations[packetId] >= totalWatchers[srcChainSlug]) return true;

        if (block.timestamp - proposeTime >= timeoutInSeconds) return true;
        return false;
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

    function _getVerificationFees(
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
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

    /**
     * @notice updates socket_
     * @param socket_ address of Notary
     */
    function setSocket(address socket_) external onlyOwner {
        socket = ISocket(socket_);
        emit SocketSet(socket_);
    }

    /**
     * @notice pause/unpause execution
     * @param tripGlobalFuse_ bool indicating verification is active or not
     */
    function trip(bool tripGlobalFuse_) external onlyOwner {
        tripGlobalFuse = tripGlobalFuse_;
        emit SwitchboardTripped(tripGlobalFuse_);
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
