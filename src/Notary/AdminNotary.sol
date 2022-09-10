// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/INotary.sol";
import "../utils/AccessControl.sol";
import "../interfaces/IAccumulator.sol";
import "../interfaces/ISignatureVerifier.sol";

contract AdminNotary is INotary, AccessControl(msg.sender) {
    struct PacketDetails {
        bool isPaused;
        bytes32 remoteRoots;
        uint256 attestations;
        uint256 timeRecord;
    }

    uint256 private immutable _chainId;
    ISignatureVerifier private _signatureVerifier;

    // attester => accumAddr + chainId + packetId => is attested
    mapping(address => mapping(uint256 => bool)) public isAttested;

    // chainId => total attesters registered
    mapping(uint256 => uint256) public totalAttestors;

    // accumAddr + chainId
    mapping(uint256 => bool) public isFast;

    // accumAddr + chainId + packetId
    mapping(uint256 => PacketDetails) private _packetDetails;

    constructor(address signatureVerifier_, uint256 chainId_) {
        _chainId = chainId_;
        _signatureVerifier = ISignatureVerifier(signatureVerifier_);
    }

    function verifyAndSeal(
        address accumAddress_,
        uint256 remoteChainId_,
        bytes calldata signature_
    ) external override {
        (bytes32 root, uint256 packetId) = IAccumulator(accumAddress_)
            .sealPacket();

        address attester = _signatureVerifier.recoverSigner(
            _chainId,
            accumAddress_,
            packetId,
            root,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();
        emit PacketVerifiedAndSealed(accumAddress_, packetId, signature_);
    }

    function challengeSignature(
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_,
        bytes calldata signature_
    ) external override {
        address attester = _signatureVerifier.recoverSigner(
            _chainId,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );
        bytes32 root = IAccumulator(accumAddress_).getRootById(packetId_);

        if (root == root_) {
            emit ChallengedSuccessfully(
                attester,
                accumAddress_,
                packetId_,
                msg.sender,
                0
            );
        }
    }

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

        _verifyAndUpdateAttestations(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );

        packedDetails.remoteRoots = root_;
        packedDetails.timeRecord = block.timestamp;
        emit Proposed(remoteChainId_, accumAddress_, packetId_, root_);
    }

    function confirmRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external {
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
            root_,
            signature_
        );

        emit RootConfirmed(attester, accumAddress_, packetId_);
    }

    function _verifyAndUpdateAttestations(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) private returns (address attester) {
        attester = _signatureVerifier.recoverSigner(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();

        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        PacketDetails storage packedDetails = _packetDetails[packedId];

        if (isAttested[attester][packedId]) revert AlreadyAttested();

        isAttested[attester][packedId] = true;
        packedDetails.attestations++;
    }

    function getPacketStatus(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    ) public view returns (PacketStatus status) {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        uint256 accumId = _pack(accumAddress_, remoteChainId_);
        uint256 packetArrivedAt = _packetDetails[packedId].timeRecord;

        if (packetArrivedAt == 0) return PacketStatus.NOT_PROPOSED;

        // if paused at dest
        if (_packetDetails[packedId].isPaused) return PacketStatus.PAUSED;

        if (isFast[accumId]) {
            if (
                _packetDetails[packedId].attestations !=
                totalAttestors[remoteChainId_]
            ) return PacketStatus.PROPOSED;
        }

        return PacketStatus.CONFIRMED;
    }

    function getPacketDetails(
        address accumAddress_,
        uint256 remoteChainId_,
        uint256 packetId_
    )
        external
        view
        returns (
            bool isConfirmed,
            uint256 packetArrivedAt,
            bytes32 root
        )
    {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        PacketStatus status = getPacketStatus(
            accumAddress_,
            remoteChainId_,
            packetId_
        );

        if (status == PacketStatus.CONFIRMED) isConfirmed = true;
        root = _packetDetails[packedId].remoteRoots;
        packetArrivedAt = _packetDetails[packedId].timeRecord;
    }

    function pausePacketOnDest(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) external {
        uint256 packedId = _packWithPacketId(
            accumAddress_,
            remoteChainId_,
            packetId_
        );
        PacketDetails storage packedDetails = _packetDetails[packedId];

        if (packedDetails.remoteRoots != root_) revert RootNotFound();
        if (packedDetails.isPaused) revert PacketPaused();

        // add check for msg.sender
        packedDetails.isPaused = true;

        emit PausedPacket(accumAddress_, packetId_, msg.sender);
    }

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

    function grantAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        if (_hasRole(_attesterRole(remoteChainId_), attester_))
            revert AttesterExists();
        _grantRole(_attesterRole(remoteChainId_), attester_);
        totalAttestors[remoteChainId_]++;
    }

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
        _signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function _attesterRole(uint256 chainId_) internal pure returns (bytes32) {
        return bytes32(chainId_);
    }

    function signatureVerifier() external view returns (address) {
        return address(_signatureVerifier);
    }

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

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function addAccumulator(
        address accumAddress_,
        uint256 remoteChainId_,
        bool isFast_
    ) external onlyOwner {
        uint256 accumId = _pack(accumAddress_, remoteChainId_);
        isFast[accumId] = isFast_;
    }

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
