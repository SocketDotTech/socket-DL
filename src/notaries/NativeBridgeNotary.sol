// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../utils/AccessControl.sol";
import "../utils/ReentrancyGuard.sol";
import "../libraries/AddressAliasHelper.sol";

import "../interfaces/INotary.sol";
import "../interfaces/IAccumulator.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../interfaces/native-bridge/IInbox.sol";
import "../interfaces/native-bridge/IOutbox.sol";
import "../interfaces/native-bridge/IBridge.sol";

contract NativeBridgeNotary is INotary, AccessControl, ReentrancyGuard {
    uint256 private immutable _chainSlug;
    ISignatureVerifier public signatureVerifier;

    address public remoteTarget;
    IInbox public inbox;

    error InvalidSender();

    // accumAddr|chainSlug|packetId
    mapping(uint256 => bytes32) private _remoteRoots;

    event UpdatedRemoteTarget(address remoteTarget);

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_,
        address inbox_
    ) AccessControl(msg.sender) {
        _chainSlug = chainSlug_;
        signatureVerifier = ISignatureVerifier(signatureVerifier_);

        remoteTarget = remoteTarget_;
        inbox = IInbox(inbox_);
    }

    function updateRemoteTarget(address remoteTarget_) external onlyOwner {
        remoteTarget = remoteTarget_;
        emit UpdatedRemoteTarget(remoteTarget_);
    }

    /// @inheritdoc INotary
    function seal(
        address accumAddress_,
        uint256[] calldata bridgeParams,
        bytes calldata signature_
    ) external payable override nonReentrant {
        (
            bytes32 root,
            uint256 packetCount,
            uint256 remoteChainSlug
        ) = IAccumulator(accumAddress_).sealPacket{value: msg.value}(
                bridgeParams
            );

        uint256 packetId = _getPacketId(accumAddress_, _chainSlug, packetCount);

        address attester = signatureVerifier.recoverSigner(
            remoteChainSlug,
            packetId,
            root,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainSlug), attester))
            revert InvalidAttester();
        emit PacketVerifiedAndSealed(
            attester,
            accumAddress_,
            packetId,
            signature_
        );
    }

    /// @inheritdoc INotary
    function attest(
        uint256 packetId_,
        bytes32 root_,
        bytes calldata
    ) external override {
        _verifySender();

        if (_remoteRoots[packetId_] != bytes32(0)) revert AlreadyAttested();
        _remoteRoots[packetId_] = root_;

        emit PacketProposed(packetId_, root_);
        emit PacketAttested(msg.sender, packetId_);
    }

    function _verifySender() internal view {
        //check sender address
        if (
            (_chainSlug == 42161 || _chainSlug == 421613) &&
            msg.sender != AddressAliasHelper.applyL1ToL2Alias(remoteTarget)
        ) revert InvalidAttester();

        if (_chainSlug == 1 || _chainSlug == 5) {
            IBridge bridge = inbox.bridge();
            if (msg.sender != address(bridge)) revert InvalidSender();

            IOutbox outbox = IOutbox(bridge.activeOutbox());
            address l2Sender = outbox.l2ToL1Sender();
            if (l2Sender != remoteTarget) revert InvalidAttester();
        }
    }

    /**
     * @notice updates root for given packet id
     * @param packetId_ id of packet to be updated
     * @param newRoot_ new root
     */
    function updatePacketRoot(uint256 packetId_, bytes32 newRoot_)
        external
        onlyOwner
    {
        bytes32 oldRoot = _remoteRoots[packetId_];
        _remoteRoots[packetId_] = newRoot_;

        emit PacketRootUpdated(packetId_, oldRoot, newRoot_);
    }

    /// @inheritdoc INotary
    function getPacketStatus(uint256 packetId_)
        external
        view
        override
        returns (PacketStatus status)
    {
        return
            _remoteRoots[packetId_] == bytes32(0)
                ? PacketStatus.NOT_PROPOSED
                : PacketStatus.PROPOSED;
    }

    /// @inheritdoc INotary
    function getPacketDetails(uint256 packetId_)
        external
        view
        override
        returns (
            PacketStatus,
            uint256,
            uint256,
            bytes32
        )
    {
        bytes32 root = _remoteRoots[packetId_];
        PacketStatus status = root == bytes32(0)
            ? PacketStatus.NOT_PROPOSED
            : PacketStatus.PROPOSED;

        return (status, 0, 0, root);
    }

    /**
     * @notice returns the remote root for given `packetId_`
     * @param packetId_ packed id
     */
    function getRemoteRoot(uint256 packetId_)
        external
        view
        override
        returns (bytes32)
    {
        return _remoteRoots[packetId_];
    }

    /**
     * @notice adds an attester for `remoteChainSlug_` chain
     * @param remoteChainSlug_ remote chain id
     * @param attester_ attester address
     */
    function grantAttesterRole(uint256 remoteChainSlug_, address attester_)
        external
        onlyOwner
    {
        if (_hasRole(_attesterRole(remoteChainSlug_), attester_))
            revert AttesterExists();

        _grantRole(_attesterRole(remoteChainSlug_), attester_);
    }

    /**
     * @notice removes an attester from `remoteChainSlug_` chain list
     * @param remoteChainSlug_ remote chain id
     * @param attester_ attester address
     */
    function revokeAttesterRole(uint256 remoteChainSlug_, address attester_)
        external
        onlyOwner
    {
        if (!_hasRole(_attesterRole(remoteChainSlug_), attester_))
            revert AttesterNotFound();

        _revokeRole(_attesterRole(remoteChainSlug_), attester_);
    }

    function _attesterRole(uint256 chainSlug_) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }

    /**
     * @notice returns the current chain id
     */
    function chainSlug() external view returns (uint256) {
        return _chainSlug;
    }

    /**
     * @notice updates signatureVerifier_
     * @param signatureVerifier_ address of Signature Verifier
     */
    function setSignatureVerifier(address signatureVerifier_)
        external
        onlyOwner
    {
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function _getPacketId(
        address accumAddr_,
        uint256 chainSlug_,
        uint256 packetCount_
    ) internal pure returns (uint256 packetId) {
        packetId =
            (chainSlug_ << 224) |
            (uint256(uint160(accumAddr_)) << 64) |
            packetCount_;
    }

    function _getChainSlug(uint256 packetId_)
        internal
        pure
        returns (uint256 chainSlug_)
    {
        chainSlug_ = uint32(packetId_ >> 224);
    }
}
