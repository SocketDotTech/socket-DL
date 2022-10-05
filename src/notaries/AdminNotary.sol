// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/INotary.sol";
import "../interfaces/IAccumulator.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../utils/AccessControl.sol";

contract AdminNotary is INotary, AccessControl(msg.sender) {
    uint256 private immutable _chainId;
    ISignatureVerifier public signatureVerifier;

    // attester => accumAddr|chainId|packetId => is attested
    mapping(address => mapping(uint256 => bool)) public isAttested;

    // chainId => total attesters registered
    mapping(uint256 => uint256) public totalAttestors;

    // accumAddr|chainId|packetId
    mapping(uint256 => PacketDetails) private _packetDetails;

    constructor(address signatureVerifier_, uint256 chainId_) {
        _chainId = chainId_;
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
    }

    /// @inheritdoc INotary
    function seal(address accumAddress_, bytes calldata signature_)
        external
        override
    {
        (bytes32 root, uint256 packetId, uint256 remoteChainId) = IAccumulator(
            accumAddress_
        ).sealPacket();

        address attester = signatureVerifier.recoverSigner(
            _chainId,
            remoteChainId,
            accumAddress_,
            packetId,
            root,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainId), attester))
            revert InvalidAttester();
        emit PacketVerifiedAndSealed(
            attester,
            accumAddress_,
            packetId,
            signature_
        );
    }

    /// @inheritdoc INotary
    function challengeSignature(
        bytes32 root_,
        uint256 packetId_,
        uint256 destChainId_,
        address accumAddress_,
        bytes calldata signature_
    ) external override {
        bytes32 root = IAccumulator(accumAddress_).getRootById(packetId_);

        address attester = signatureVerifier.recoverSigner(
            _chainId,
            destChainId_,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );

        if (root == root_ && root != bytes32(0)) {
            emit ChallengedSuccessfully(
                attester,
                accumAddress_,
                packetId_,
                msg.sender,
                0
            );
        }
    }

    /// @inheritdoc INotary
    function propose(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external override {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );

        PacketDetails storage packedDetails = _packetDetails[packedId];
        if (packedDetails.remoteRoots != 0) revert AlreadyProposed();

        packedDetails.remoteRoots = root_;
        packedDetails.timeRecord = block.timestamp;

        _verifyAndUpdateAttestations(
            remoteChainId_,
            accumAddress_,
            packetId_,
            packedId,
            root_,
            signature_
        );

        emit Proposed(remoteChainId_, accumAddress_, packetId_, root_);
    }

    /// @inheritdoc INotary
    function confirmRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external override {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );

        if (_packetDetails[packedId].isPaused) revert PacketPaused();
        if (_packetDetails[packedId].remoteRoots != root_)
            revert RootNotFound();

        address attester = _verifyAndUpdateAttestations(
            remoteChainId_,
            accumAddress_,
            packetId_,
            packedId,
            root_,
            signature_
        );

        emit RootConfirmed(attester, accumAddress_, packetId_, remoteChainId_);
    }

    function _verifyAndUpdateAttestations(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        uint256 packedId,
        bytes32 root_,
        bytes calldata signature_
    ) private returns (address attester) {
        attester = signatureVerifier.recoverSigner(
            remoteChainId_,
            _chainId,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();

        PacketDetails storage packedDetails = _packetDetails[packedId];
        if (isAttested[attester][packedId]) revert AlreadyAttested();

        isAttested[attester][packedId] = true;
        packedDetails.attestations++;
    }

    /// @inheritdoc INotary
    function getPacketStatus(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) public view override returns (PacketStatus status) {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );

        PacketDetails memory packet = _packetDetails[packedId];
        uint256 packetArrivedAt = packet.timeRecord;

        if (packetArrivedAt == 0) return PacketStatus.NOT_PROPOSED;

        // if paused at dest
        if (packet.isPaused) return PacketStatus.PAUSED;

        return PacketStatus.PROPOSED;
    }

    /// @inheritdoc INotary
    function getPacketDetails(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    )
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
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        status = getPacketStatus(accumAddress_, remoteChainId_, packetId_);

        PacketDetails memory packet = _packetDetails[packedId];
        root = packet.remoteRoots;
        packetArrivedAt = packet.timeRecord;
        pendingAttestations =
            totalAttestors[remoteChainId_] -
            packet.attestations;
    }

    /**
     * @notice pauses the packet on destination
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ src chain id
     * @param packetId_ packed id
     * @param root_ root hash
     */
    function pausePacketOnDest(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_,
        bytes32 root_
    ) external onlyOwner {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        PacketDetails storage packedDetails = _packetDetails[packedId];

        if (packedDetails.remoteRoots != root_) revert RootNotFound();
        if (packedDetails.isPaused) revert PacketPaused();

        packedDetails.isPaused = true;
        emit PausedPacket(accumAddress_, packetId_, msg.sender);
    }

    /**
     * @notice unpause the packet on destination
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ src chain id
     * @param packetId_ packed id
     */
    function acceptPausedPacket(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) external onlyOwner {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        PacketDetails storage packedDetails = _packetDetails[packedId];

        if (!packedDetails.isPaused) revert PacketNotPaused();
        packedDetails.isPaused = false;
        emit PacketUnpaused(accumAddress_, packetId_);
    }

    /**
     * @notice adds an attester for `remoteChainId_` chain
     * @param remoteChainId_ dest chain id
     * @param attester_ attester address
     */
    function grantAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        if (_hasRole(_attesterRole(remoteChainId_), attester_))
            revert AttesterExists();

        _grantRole(_attesterRole(remoteChainId_), attester_);
        totalAttestors[remoteChainId_]++;
    }

    /**
     * @notice removes an attester from `remoteChainId_` chain list
     * @param remoteChainId_ dest chain id
     * @param attester_ attester address
     */
    function revokeAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        if (!_hasRole(_attesterRole(remoteChainId_), attester_))
            revert AttesterNotFound();

        _revokeRole(_attesterRole(remoteChainId_), attester_);
        totalAttestors[remoteChainId_]--;
    }

    function _setSignatureVerifier(address signatureVerifier_) private {
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function _attesterRole(uint256 chainId_) internal pure returns (bytes32) {
        return bytes32(chainId_);
    }

    /**
     * @notice returns the confirmations received by a packet
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ src chain id
     * @param packetId_ packed id
     */
    function getConfirmations(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) external view returns (uint256) {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        return _packetDetails[packedId].attestations;
    }

    /**
     * @notice returns the remote root for given `packetId_`
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainId_ src chain id
     * @param packetId_ packed id
     */
    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view override returns (bytes32) {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        return _packetDetails[packedId].remoteRoots;
    }

    /**
     * @notice returns the current chain id
     */
    function chainId() external view returns (uint256) {
        return _chainId;
    }

    /**
     * @notice updates signatureVerifier_
     * @param signatureVerifier_ address of Signature Verifier
     */
    function setSignatureVerifier(address signatureVerifier_)
        external
        onlyOwner
    {
        _setSignatureVerifier(signatureVerifier_);
    }

    function _packWithPacketId(
        address accumAddr_,
        uint256 chainId_,
        uint256 packetId_
    ) internal pure returns (uint256 packed) {
        packed =
            (uint256(uint160(accumAddr_)) << 96) |
            (chainId_ << 64) |
            packetId_;
    }

    function _unpackWithPacketId(uint256 accumId_)
        internal
        pure
        returns (
            address accumAddr_,
            uint256 chainId_,
            uint256 packetId_
        )
    {
        accumAddr_ = address(uint160(accumId_ >> 96));
        packetId_ = uint64(accumId_);
        chainId_ = uint32(accumId_ >> 64);
    }

    function _pack(address accumAddr_, uint256 chainId_)
        internal
        pure
        returns (uint256 packed)
    {
        packed = (uint256(uint160(accumAddr_)) << 32) | chainId_;
    }

    function _unpack(uint256 accumId_)
        internal
        pure
        returns (address accumAddr_, uint256 chainId_)
    {
        accumAddr_ = address(uint160(accumId_ >> 32));
        chainId_ = uint32(accumId_);
    }
}
