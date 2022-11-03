// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/INotary.sol";
import "../interfaces/IAccumulator.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../utils/AccessControl.sol";
import "../utils/ReentrancyGuard.sol";

contract AdminNotary is INotary, AccessControl(msg.sender), ReentrancyGuard {
    uint256 private immutable _chainSlug;
    ISignatureVerifier public signatureVerifier;

    // attester => accumAddr|chainSlug|packetId => is attested
    mapping(address => mapping(uint256 => bool)) public isAttested;

    // chainSlug => total attesters registered
    mapping(uint256 => uint256) public totalAttestors;

    // accumAddr|chainSlug|packetId
    mapping(uint256 => PacketDetails) private _packetDetails;

    constructor(address signatureVerifier_, uint32 chainSlug_) {
        _chainSlug = chainSlug_;
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
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
                bridgeParams,
                signature_
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
        bytes calldata signature_
    ) external override {
        address attester = signatureVerifier.recoverSigner(
            _chainSlug,
            packetId_,
            root_,
            signature_
        );

        if (!_hasRole(_attesterRole(_getChainSlug(packetId_)), attester))
            revert InvalidAttester();

        _updatePacketDetails(attester, packetId_, root_);
        emit PacketAttested(attester, packetId_);
    }

    function _updatePacketDetails(
        address attester_,
        uint256 packetId_,
        bytes32 root_
    ) private {
        PacketDetails storage packedDetails = _packetDetails[packetId_];
        if (isAttested[attester_][packetId_]) revert AlreadyAttested();

        if (_packetDetails[packetId_].remoteRoots == bytes32(0)) {
            packedDetails.remoteRoots = root_;
            packedDetails.timeRecord = block.timestamp;

            emit PacketProposed(packetId_, root_);
        } else if (_packetDetails[packetId_].remoteRoots != root_)
            revert RootNotFound();

        isAttested[attester_][packetId_] = true;
        packedDetails.attestations++;
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
        PacketDetails storage packedDetails = _packetDetails[packetId_];
        bytes32 oldRoot = packedDetails.remoteRoots;
        packedDetails.remoteRoots = newRoot_;

        emit PacketRootUpdated(packetId_, oldRoot, newRoot_);
    }

    /// @inheritdoc INotary
    function getPacketStatus(uint256 packetId_)
        public
        view
        override
        returns (PacketStatus status)
    {
        PacketDetails memory packet = _packetDetails[packetId_];
        uint256 packetArrivedAt = packet.timeRecord;

        if (packetArrivedAt == 0) return PacketStatus.NOT_PROPOSED;
        return PacketStatus.PROPOSED;
    }

    /// @inheritdoc INotary
    function getPacketDetails(uint256 packetId_)
        external
        view
        override
        returns (
            PacketStatus status,
            uint256 packetArrivedAt,
            uint256 pendingAttestations,
            bytes32 root
        )
    {
        status = getPacketStatus(packetId_);

        PacketDetails memory packet = _packetDetails[packetId_];
        root = packet.remoteRoots;
        packetArrivedAt = packet.timeRecord;
        pendingAttestations =
            totalAttestors[_getChainSlug(packetId_)] -
            packet.attestations;
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
        totalAttestors[remoteChainSlug_]++;
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
        totalAttestors[remoteChainSlug_]--;
    }

    function _attesterRole(uint256 chainSlug_) internal pure returns (bytes32) {
        return bytes32(chainSlug_);
    }

    /**
     * @notice returns the attestations received by a packet
     * @param packetId_ packed id
     */
    function getAttestationCount(uint256 packetId_)
        external
        view
        returns (uint256)
    {
        return _packetDetails[packetId_].attestations;
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
        return _packetDetails[packetId_].remoteRoots;
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
