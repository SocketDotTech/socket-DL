// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./SwitchboardBase.sol";

/**
 * @title FastSwitchboard contract
 * @dev This contract implements a fast version of the SwitchboardBase contract
 * that enables packet attestations and watchers registration.
 */
contract FastSwitchboard is SwitchboardBase {
    // dstChainSlug => totalWatchers registered
    mapping(uint32 => uint256) public totalWatchers;

    // used to track which watcher have attested a root
    // watcher => root => isAttested
    mapping(address => mapping(bytes32 => bool)) public isAttested;

    // used to detect when enough attestations are reached
    // root => attestationCount
    mapping(bytes32 => uint256) public attestations;

    // mapping to store if root is valid
    // marked when all watchers have attested for a root
    // root => isValid
    mapping(bytes32 => bool) public isRootValid;

    // Event emitted when a new socket is set
    event SocketSet(address newSocket);

    // Event emitted when a proposal is attested
    event ProposalAttested(
        bytes32 packetId,
        uint256 proposalCount,
        bytes32 root,
        address watcher,
        uint256 attestationsCount
    );

    // Error emitted when a watcher already has role while granting
    error WatcherFound();

    // Error emitted when a watcher is not found while attesting or while revoking role
    error WatcherNotFound();

    // Error emitted when a root is already attested by a specific watcher.
    // This is hit even if they are attesting a new proposalCount with same root.
    error AlreadyAttested();

    // Error emitted if grant/revoke is tried for watcher role using generic grant/revoke functions.
    // Watcher role is handled seperately bacause totalWatchers and fees need to be updated along with role change.
    error InvalidRole();

    // Error emitted while attesting if root is zero or it doesnt match the root on socket for given proposal
    // helps in cases where attest tx has been sent but root changes on socket due to reorgs.
    error InvalidRoot();

    /**
     * @dev Constructor function for the FastSwitchboard contract
     * @param owner_ Address of the owner of the contract
     * @param socket_ Address of the socket contract
     * @param chainSlug_ Chain slug of the chain where the contract is deployed
     * @param timeoutInSeconds_ Timeout in seconds after which proposals become valid if not tripped
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
     * @param proposalCount_ Proposal count
     * @param root_ Root of the packet
     * @param signature_ Signature of the watcher
     * @notice we are attesting a root uniquely identified with packetId and proposalCount. However,
     * there can be multiple proposals for same root. To avoid need to re-attest for different proposals
     *  with same root, we are storing attestations against root instead of packetId and proposalCount.
     */
    function attest(
        bytes32 packetId_,
        uint256 proposalCount_,
        bytes32 root_,
        bytes calldata signature_
    ) external {
        uint32 srcChainSlug = uint32(uint256(packetId_) >> 224);

        bytes32 root = socket__.packetIdRoots(
            packetId_,
            proposalCount_,
            address(this)
        );
        if (root == bytes32(0)) revert InvalidRoot();
        if (root != root_) revert InvalidRoot();

        address watcher = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    address(this),
                    chainSlug,
                    packetId_,
                    proposalCount_,
                    root_
                )
            ),
            signature_
        );

        if (isAttested[watcher][root]) revert AlreadyAttested();
        if (!_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug, watcher))
            revert WatcherNotFound();

        isAttested[watcher][root] = true;
        ++attestations[root];

        if (attestations[root] >= totalWatchers[srcChainSlug])
            isRootValid[root] = true;

        emit ProposalAttested(
            packetId_,
            proposalCount_,
            root,
            watcher,
            attestations[root]
        );
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function setFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint128 switchboardFees_,
        uint128 verificationOverheadFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    switchboardFees_,
                    verificationOverheadFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);
        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }

        // switchboardFees_ input is amount needed per watcher, multipled and stored on chain to avoid watcher set tracking offchain.
        // switchboardFees_ are paid to switchboard per packet
        // verificationOverheadFees_ are paid to executor per message
        Fees memory feesObject = Fees({
            switchboardFees: switchboardFees_ *
                uint128(totalWatchers[dstChainSlug_]),
            verificationOverheadFees: verificationOverheadFees_
        });

        fees[dstChainSlug_] = feesObject;
        emit SwitchboardFeesSet(dstChainSlug_, feesObject);
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPacket(
        bytes32 root_,
        bytes32 packetId_,
        uint256 proposalCount_,
        uint32 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        uint64 packetCount = uint64(uint256(packetId_));

        // any relevant trips triggered or invalid packet count.
        if (
            isGlobalTipped ||
            isPathTripped[srcChainSlug_] ||
            isProposalTripped[packetId_][proposalCount_] ||
            packetCount < initialPacketCount[srcChainSlug_]
        ) return false;

        // root has enough attestations
        if (isRootValid[root_]) return true;

        // this makes packets valid even if all watchers have not attested
        // used to make the system work when watchers are inactive due to infra etc problems
        if (block.timestamp - proposeTime_ > timeoutInSeconds) return true;

        // not enough attestations and timeout not hit
        return false;
    }

    /**
     * @notice adds a watcher for `srcChainSlug_` chain
     * @param srcChainSlug_ chain slug of the chain where the watcher is being added
     * @param watcher_ watcher address
     */
    function grantWatcherRole(
        uint32 srcChainSlug_,
        address watcher_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_))
            revert WatcherFound();
        _grantRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_);

        Fees storage fees = fees[srcChainSlug_];
        uint128 watchersBefore = uint128(totalWatchers[srcChainSlug_]);

        // edge case handled by calling setFees function after boorstrapping is done.
        if (watchersBefore != 0 && fees.switchboardFees != 0)
            fees.switchboardFees =
                (fees.switchboardFees * (watchersBefore + 1)) /
                watchersBefore;

        ++totalWatchers[srcChainSlug_];
    }

    /**
     * @notice removes a watcher from `srcChainSlug_` chain list
     * @param srcChainSlug_ chain slug of the chain where the watcher is being removed
     * @param watcher_ watcher address
     */
    function revokeWatcherRole(
        uint32 srcChainSlug_,
        address watcher_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (!_hasRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_))
            revert WatcherNotFound();
        _revokeRoleWithSlug(WATCHER_ROLE, srcChainSlug_, watcher_);

        Fees storage fees = fees[srcChainSlug_];
        uint128 watchersBefore = uint128(totalWatchers[srcChainSlug_]);

        // revoking all watchers is an extreme case not expected to be hit after setup is done.
        if (watchersBefore > 1 && fees.switchboardFees != 0)
            fees.switchboardFees =
                (fees.switchboardFees * (watchersBefore - 1)) /
                watchersBefore;

        totalWatchers[srcChainSlug_]--;
    }

    /**
     * @notice returns true if non watcher role. Used to avoid granting watcher role directly
     * @dev If adding any new role to FastSwitchboard, have to add it here as well to make sure it can be set
     */
    function isNonWatcherRole(bytes32 role_) public pure returns (bool) {
        if (
            role_ == TRIP_ROLE ||
            role_ == UN_TRIP_ROLE ||
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

        uint256 totalRoles = roleNames_.length;
        for (uint256 index = 0; index < totalRoles; ) {
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
            // we will reach block gas limit before this overflows
            unchecked {
                ++index;
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
        uint256 totalRoles = roleNames_.length;
        for (uint256 index = 0; index < totalRoles; ) {
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
            // we will reach block gas limit before this overflows
            unchecked {
                ++index;
            }
        }
    }
}
