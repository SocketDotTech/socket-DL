// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";
import "../../libraries/SignatureVerifierLib.sol";
import {ATTEST_GAS_LIMIT_UPDATE_SIG_IDENTIFIER} from "../../utils/SigIdentifiers.sol";

/**
 * @title FastSwitchboard contract
 * @dev This contract implements a fast version of the SwitchboardBase contract
 * that enables packet attestations and watchers registration.
 */
contract FastSwitchboard is SwitchboardBase {
    // mapping to store if packet is valid
    mapping(bytes32 => bool) public isPacketValid;

    // dst chain slug => total watchers registered
    mapping(uint32 => uint256) public totalWatchers;

    // dst chain slug => attest gas limit
    mapping(uint32 => uint256) public attestGasLimit;

    // attester => packetId => is attested
    mapping(address => mapping(bytes32 => bool)) public isAttested;

    // packetId => total attestations
    mapping(bytes32 => uint256) public attestations;

    // Event emitted when a new socket is set
    event SocketSet(address newSocket);
    // Event emitted when a packet is attested
    event PacketAttested(bytes32 packetId, address attester);
    // Event emitted when the attest gas limit is set
    event AttestGasLimitSet(uint32 dstChainSlug, uint256 attestGasLimit);

    // Error emitted when a watcher is found
    error WatcherFound();
    // Error emitted when a watcher is not found
    error WatcherNotFound();
    // Error emitted when a packet is already attested
    error AlreadyAttested();

    /**
     * @dev Constructor function for the FastSwitchboard contract
     * @param owner_ Address of the owner of the contract
     * @param socket_ Address of the socket contract
     * @param gasPriceOracle_ Address of the gas price oracle contract
     * @param chainSlug_ Chain slug of the chain where the contract is deployed
     * @param timeoutInSeconds_ Timeout in seconds for the packets
     * @param signatureVerifier_ The address of the signature verifier contract
     */
    constructor(
        address owner_,
        address socket_,
        address gasPriceOracle_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        SwitchboardBase(gasPriceOracle_, socket_, chainSlug_, timeoutInSeconds_, signatureVerifier_)
    {}

    /**
     * @dev Function to attest a packet
     * @param packetId_ Packet ID
     * @param signature_ Signature of the packet
     */
    function attest(bytes32 packetId_, bytes calldata signature_) external {
        uint32 srcChainSlug = uint32(uint256(packetId_) >> 224);
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(address(this), srcChainSlug, chainSlug, packetId_)
            ),
            signature_
        );

        if (isAttested[watcher][packetId_]) revert AlreadyAttested();
        if (!_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug, watcher))
            revert WatcherNotFound();

        isAttested[watcher][packetId_] = true;
        attestations[packetId_]++;

        if (attestations[packetId_] >= totalWatchers[srcChainSlug])
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
        if (isPacketValid[packetId_]) return true;
        if (block.timestamp - proposeTime_ > timeoutInSeconds) return true;
        return false;
    }

    function _getMinSwitchboardFees(
        uint32 dstChainSlug_,
        uint256 dstRelativeGasPrice_
    ) internal view override returns (uint256) {
        // assumption: number of watchers are going to be same on all chains for particular chain slug
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
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 attestGasLimit_,
        bytes calldata signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    ATTEST_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    attestGasLimit_
                )
            ),
            signature_
        );
        _checkRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            dstChainSlug_,
            gasLimitUpdater
        );

        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        attestGasLimit[dstChainSlug_] = attestGasLimit_;
        emit AttestGasLimitSet(dstChainSlug_, attestGasLimit_);
    }

    /**
     * @notice adds a watcher for `srcChainSlug_` chain
     * @param watcher_ watcher address
     */
    function grantWatcherRole(
        uint32 srcChainSlug_,
        address watcher_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_))
            revert WatcherFound();
        _grantRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_);

        totalWatchers[srcChainSlug_]++;
    }

    /**
     * @notice removes a watcher from `srcChainSlug_` chain list
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(
        uint32 srcChainSlug_,
        address watcher_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (!_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_))
            revert WatcherNotFound();
        _revokeRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_);

        totalWatchers[srcChainSlug_]--;
    }
}
