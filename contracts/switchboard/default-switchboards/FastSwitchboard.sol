// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";
import "../../libraries/SignatureVerifierLib.sol";
import {WATCHER_ROLE, GAS_LIMIT_UPDATER_ROLE} from "../../utils/AccessRoles.sol";

contract FastSwitchboard is SwitchboardBase {
    uint256 public immutable timeoutInSeconds;
    mapping(bytes32 => bool) public isPacketValid;

    // dst chain slug => total watchers registered
    mapping(uint256 => uint256) public totalWatchers;

    // dst chain slug => attest gas limit
    mapping(uint256 => uint256) public attestGasLimit;

    // attester => packetId => is attested
    mapping(address => mapping(bytes32 => bool)) public isAttested;

    // packetId => total attestations
    mapping(bytes32 => uint256) public attestations;

    event SocketSet(address newSocket);
    event PacketAttested(bytes32 packetId, address attester);
    event AttestGasLimitSet(uint256 dstChainSlug, uint256 attestGasLimit);

    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();
    error InvalidSigLength();

    constructor(
        address owner_,
        address gasPriceOracle_,
        uint256 timeoutInSeconds_
    ) AccessControlExtended(owner_) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        timeoutInSeconds = timeoutInSeconds_;
    }

    function attest(
        bytes32 packetId_,
        uint256 srcChainSlug_,
        bytes calldata signature_
    ) external {
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(abi.encode(srcChainSlug_, packetId_)),
            signature_
        );

        if (isAttested[watcher][packetId_]) revert AlreadyAttested();
        if (!_hasRole(WATCHER_ROLE, srcChainSlug_, watcher))
            revert WatcherNotFound();

        isAttested[watcher][packetId_] = true;
        attestations[packetId_]++;

        if (attestations[packetId_] == totalWatchers[srcChainSlug_])
            isPacketValid[packetId_] = true;

        emit PacketAttested(packetId_, watcher);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packetId
     * @param proposeTime_ time at which packet was proposed
     */
    function allowPacket(
        bytes32,
        bytes32 packetId_,
        uint32 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        if (tripGlobalFuse || tripSinglePath[srcChainSlug_]) return false;

        if (
            !isPacketValid[packetId_] ||
            block.timestamp - proposeTime_ < timeoutInSeconds
        ) return false;

        return true;
    }

    function _getMinSwitchboardFees(
        uint256 dstChainSlug_,
        uint256 dstRelativeGasPrice_
    ) internal view override returns (uint256) {
        // assumption: number of watchers are going to be same on all chains for particular chain slug?
        return
            totalWatchers[dstChainSlug_] *
            attestGasLimit[dstChainSlug_] *
            dstRelativeGasPrice_;
    }

    /**
     * @notice updates attest gas limit for given chain slug
     * @param dstChainSlug_ destination chain
     * @param attestGasLimit_ average gas limit needed for attest function call
     */
    function setAttestGasLimit(
        uint256 dstChainSlug_,
        uint256 attestGasLimit_
    ) external onlyRoleWithChainSlug(GAS_LIMIT_UPDATER_ROLE, dstChainSlug_) {
        attestGasLimit[dstChainSlug_] = attestGasLimit_;
        emit AttestGasLimitSet(dstChainSlug_, attestGasLimit_);
    }

    /**
     * @notice adds a watcher for `srcChainSlug_` chain
     * @param watcher_ watcher address
     */
    function grantWatcherRole(
        uint256 srcChainSlug_,
        address watcher_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_hasRole(WATCHER_ROLE, srcChainSlug_, watcher_))
            revert WatcherFound();
        _grantRole(WATCHER_ROLE, srcChainSlug_, watcher_);

        totalWatchers[srcChainSlug_]++;
    }

    /**
     * @notice removes a watcher from `srcChainSlug_` chain list
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(
        uint256 srcChainSlug_,
        address watcher_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (!_hasRole(WATCHER_ROLE, srcChainSlug_, watcher_))
            revert WatcherNotFound();
        _revokeRole(WATCHER_ROLE, srcChainSlug_, watcher_);

        totalWatchers[srcChainSlug_]--;
    }
}
