// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";

contract FastSwitchboard is SwitchboardBase {
    uint256 public immutable timeoutInSeconds;

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
    error InvalidSigLength();

    constructor(
        address owner_,
        address oracle_,
        uint256 timeoutInSeconds_
    ) AccessControl(owner_) {
        oracle = IOracle(oracle_);
        timeoutInSeconds = timeoutInSeconds_;
    }

    function attest(
        uint256 packetId,
        uint256 srcChainSlug,
        bytes calldata signature
    ) external {
        address watcher = _recoverSigner(srcChainSlug, packetId, signature);

        if (isAttested[watcher][packetId]) revert AlreadyAttested();
        if (!_hasRole(_watcherRole(srcChainSlug), watcher))
            revert WatcherNotFound();

        isAttested[watcher][packetId] = true;
        attestations[packetId]++;

        emit PacketAttested(packetId, watcher);
    }

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

        // to handle the situation: if a watcher is removed after it attested the packet
        if (attestations[packetId] >= totalWatchers[srcChainSlug]) return true;

        if (block.timestamp - proposeTime >= timeoutInSeconds) return true;
        return false;
    }

    function _getSwitchboardFees(
        uint256 dstChainSlug,
        uint256 dstRelativeGasPrice
    ) internal view override returns (uint256) {
        // assumption: number of watchers are going to be same on all chains for particular chain slug?
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

    // TODO: watchers are chain specific hence letting them act globally seems weird, need to rethink
    /**
     * @notice pause execution
     * @dev this function can only be called by watchers for pausing the global execution
     */
    function trip(
        uint256 srcChainSlug_
    ) external onlyRole(_watcherRole(srcChainSlug_)) {
        tripGlobalFuse = false;
        emit SwitchboardTripped(false);
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

    /**
     * @notice returns the address of signer recovered from input signature
     */
    function _recoverSigner(
        uint256 srcChainSlug_,
        uint256 packetId_,
        bytes memory signature_
    ) private pure returns (address signer) {
        bytes32 digest = keccak256(abi.encode(srcChainSlug_, packetId_));
        digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
        );
        (bytes32 sigR, bytes32 sigS, uint8 sigV) = _splitSignature(signature_);

        // recovered signer is checked for the valid roles later
        signer = ecrecover(digest, sigV, sigR, sigS);
    }

    /**
     * @notice splits the signature into v, r and s.
     */
    function _splitSignature(
        bytes memory signature_
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (signature_.length != 65) revert InvalidSigLength();
        assembly {
            r := mload(add(signature_, 0x20))
            s := mload(add(signature_, 0x40))
            v := byte(0, mload(add(signature_, 0x60)))
        }
    }
}
