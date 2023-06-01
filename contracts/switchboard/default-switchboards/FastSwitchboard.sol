// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SwitchboardBase.sol";

/**
 * @title FastSwitchboard contract
 * @dev This contract implements a fast version of the SwitchboardBase contract
 * that enables packet attestations and watchers registration.
 */
contract FastSwitchboard is SwitchboardBase {
    // mapping to store if root is valid
    mapping(bytes32 => bool) public isRootValid;

    // dst chain slug => total watchers registered
    mapping(uint32 => uint256) public totalWatchers;

    // attester => root => is attested
    mapping(address => mapping(bytes32 => bool)) public isAttested;

    // root => total attestations
    // @dev : (assuming here that root will be unique across system)
    mapping(bytes32 => uint256) public attestations;

    // Event emitted when a new socket is set
    event SocketSet(address newSocket);
    // Event emitted when a root is attested
    event ProposalAttested(bytes32 packetId, uint256 proposalId, bytes32 root, address attester);

    // Error emitted when a watcher is found
    error WatcherFound();
    // Error emitted when a watcher is not found
    error WatcherNotFound();
    // Error emitted when a root is already attested
    error AlreadyAttested();
    // Error emitted when role is invalid
    error InvalidRole();

    // Error emitted when role is invalid
    error InvalidRoot();

    /**
     * @dev Constructor function for the FastSwitchboard contract
     * @param owner_ Address of the owner of the contract
     * @param socket_ Address of the socket contract
     * @param chainSlug_ Chain slug of the chain where the contract is deployed
     * @param timeoutInSeconds_ Timeout in seconds for the packets
     * @param signatureVerifier_ The address of the signature verifier contract
     */
    constructor(
        address owner_,
        address socket_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        SwitchboardBase(
            socket_,
            chainSlug_,
            timeoutInSeconds_,
            signatureVerifier_
        )
    {}

    /**
     * @dev Function to attest a packet
     * @param packetId_ Packet ID
     * @param proposalId_ Proposal ID
     * @param signature_ Signature of the packet
     */
    function attest(bytes32 packetId_, uint256 proposalId_, bytes calldata signature_) external {
        uint32 srcChainSlug = uint32(uint256(packetId_) >> 224);
        bytes32 root = socket__.packetIdRoots(packetId_, proposalId_);
        if (root == bytes32(0)) revert InvalidRoot();
        // Should we change the signature to include proposalId as well? 
        address watcher = signatureVerifier__.recoverSignerFromDigest(
            keccak256(abi.encode(address(this), chainSlug, packetId_, proposalId_)),
            signature_
        );

        if (isAttested[watcher][root]) revert AlreadyAttested();
        if (!_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug, watcher))
            revert WatcherNotFound();

        isAttested[watcher][root] = true;
        attestations[root]++;

        if (attestations[root] >= totalWatchers[srcChainSlug])
            isRootValid[root] = true;

        emit ProposalAttested(packetId_, proposalId_, root, watcher);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packetId
     * @param proposalId_ proposalId
     * @param proposeTime_ time at which packet was proposed
     */
    function allowPacket(
        bytes32 root_,
        bytes32 packetId_,
        uint256 proposalId_,
        uint32 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        if (
            tripGlobalFuse || 
            tripSinglePath[srcChainSlug_] || 
            isProposalIdTripped[packetId_][proposalId_]
        ) return false;
        if (isRootValid[root_]) return true;
        if (block.timestamp - proposeTime_ > timeoutInSeconds) return true;
        return false;
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

    function isNonWatcherRole(bytes32 role_) public pure returns (bool) {
        if (
            role_ == TRIP_ROLE ||
            role_ == UNTRIP_ROLE ||
            role_ == WITHDRAW_ROLE ||
            role_ == RESCUE_ROLE ||
            role_ == GOVERNANCE_ROLE ||
            role_ == FEES_UPDATER_ROLE
        ) return true;

        return false;
    }

    /**
     * @dev Overriding this function from AccessControl to make sure owner can't grant Watcher Role directly, and should
     * only use grantWatcherRole function instead. This is to make sure watcher count remains correct
     */
    function grantRole(
        bytes32 role_,
        address grantee_
    ) external override onlyOwner {
        if (isNonWatcherRole(role_)) {
            _grantRole(role_, grantee_);
        } else {
            revert InvalidRole();
        }
    }

    /**
     * @dev Overriding this function from AccessControlExtended to make sure owner can't grant Watcher Role directly, and should
     * only use grantWatcherRole function instead. This is to make sure watcher count remains correct
     */
    function grantRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address grantee_
    ) external override onlyOwner {
        if (roleName_ != FEES_UPDATER_ROLE) revert InvalidRole();
        _grantRoleWithSlug(roleName_, chainSlug_, grantee_);
    }

    /**
     * @dev Overriding this function from AccessControl to make sure owner can't revoke Watcher Role directly, and should
     * only use revokeWatcherRole function instead. This is to make sure watcher count remains correct
     */
    function revokeRole(
        bytes32 role_,
        address grantee_
    ) external override onlyOwner {
        if (isNonWatcherRole(role_)) {
            _revokeRole(role_, grantee_);
        } else {
            revert InvalidRole();
        }
    }

    /**
     * @dev Overriding this function from AccessControlExtended to make sure owner can't revoke Watcher Role directly, and should
     * only use revokeWatcherRole function instead. This is to make sure watcher count remains correct
     */
    function revokeRoleWithSlug(
        bytes32 roleName_,
        uint32 chainSlug_,
        address grantee_
    ) external override onlyOwner {
        if (roleName_ != FEES_UPDATER_ROLE) revert InvalidRole();
        _revokeRoleWithSlug(roleName_, chainSlug_, grantee_);
    }

    /**
     * @dev Overriding this function from AccessControlExtended to make sure owner can't grant Watcher Role directly, and should
     * only use grantWatcherRole function instead. This is to make sure watcher count remains correct
     */
    function grantBatchRole(
        bytes32[] calldata roleNames_,
        uint32[] calldata slugs_,
        address[] calldata grantees_
    ) external override onlyOwner {
        if (
            roleNames_.length != grantees_.length ||
            roleNames_.length != slugs_.length
        ) revert UnequalArrayLengths();
        for (uint256 index = 0; index < roleNames_.length; index++) {
            if (isNonWatcherRole(roleNames_[index])) {
                if (slugs_[index] > 0)
                    _grantRoleWithSlug(
                        roleNames_[index],
                        slugs_[index],
                        grantees_[index]
                    );
                else _grantRole(roleNames_[index], grantees_[index]);
            } else {
                revert InvalidRole();
            }
        }
    }

    /**
     * @dev Overriding this function from AccessControlExtended to make sure owner can't revoke Watcher Role directly, and should
     * only use revokeWatcherRole function instead. This is to make sure watcher count remains correct
     */
    function revokeBatchRole(
        bytes32[] calldata roleNames_,
        uint32[] calldata slugs_,
        address[] calldata grantees_
    ) external override onlyOwner {
        if (
            roleNames_.length != grantees_.length ||
            roleNames_.length != slugs_.length
        ) revert UnequalArrayLengths();
        for (uint256 index = 0; index < roleNames_.length; index++) {
            if (isNonWatcherRole(roleNames_[index])) {
                if (slugs_[index] > 0)
                    _revokeRoleWithSlug(
                        roleNames_[index],
                        slugs_[index],
                        grantees_[index]
                    );
                else _revokeRole(roleNames_[index], grantees_[index]);
            } else {
                revert InvalidRole();
            }
        }
    }
}
