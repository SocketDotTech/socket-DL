// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/INotary.sol";
import "../utils/AccessControl.sol";
import "../interfaces/IAccumulator.sol";
import "../interfaces/ISignatureVerifier.sol";

contract AdminNotary is INotary, AccessControl(msg.sender) {
    uint256 private immutable _chainId;
    uint256 public immutable _timeoutInSeconds;
    ISignatureVerifier private _signatureVerifier;

    // remoteChainId => accumAddress => packetId => root
    mapping(uint256 => mapping(address => mapping(uint256 => bytes32)))
        private _remoteRoots;

    // attester => accumAddress => packetId => is attested
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private _isAttested;

    // accumAddress => packetId => total attestations
    mapping(address => mapping(uint256 => uint256)) public _attestations;

    // accumAddress => packetId => bool (is paused)
    mapping(address => mapping(uint256 => bool)) public _isPaused;

    // accumAddress => packetId => submitted at
    mapping(address => mapping(uint256 => uint256)) public _timeRecord;

    // chain => root => (accum, isChallenged, _timeRecord, _attestations, _isAttested(address))
    struct AccumDetails {
        uint256 remoteChainId;
        bool isFast;
    }

    mapping(uint256 => uint256) public _totalAttestors;
    mapping(address => AccumDetails) public _accumDetails;

    enum PacketStatus {
        NOT_PROPOSED,
        PROPOSED,
        PAUSED,
        CONFIRMED,
        TIMED_OUT
    }

    error AttesterExists();

    error AttesterNotFound();

    error AccumAlreadyAdded();

    error AlreadyAttested();

    error NotFastPath();

    error PacketPaused();

    error PacketNotPaused();

    error ZeroAddress();

    error RootNotFound();

    // TODO: restrict the timeout durations to a few select options
    constructor(
        address signatureVerifier_,
        uint256 chainId_,
        uint256 timeoutInSeconds_
    ) {
        _chainId = chainId_;
        _timeoutInSeconds = timeoutInSeconds_;
        _signatureVerifier = ISignatureVerifier(signatureVerifier_);
    }

    function addAccumulator(
        address accumAddress_,
        uint256 remoteChainId_,
        bool isFast_
    ) external onlyOwner {
        if (_accumDetails[accumAddress_].remoteChainId != 0)
            revert AccumAlreadyAdded();
        _accumDetails[accumAddress_] = AccumDetails(remoteChainId_, isFast_);
    }

    function setSignatureVerifier(address signatureVerifier_)
        external
        onlyOwner
    {
        _setSignatureVerifier(signatureVerifier_);
    }

    function verifyAndSeal(address accumAddress_, bytes calldata signature_)
        external
        override
    {
        (bytes32 root, uint256 packetId) = IAccumulator(accumAddress_)
            .sealPacket();

        address attester = _getAttester(
            _chainId,
            accumAddress_,
            packetId,
            root,
            signature_
        );

        if (
            !_hasRole(
                _attesterRole(_accumDetails[accumAddress_].remoteChainId),
                attester
            )
        ) revert InvalidAttester();
        emit PacketVerifiedAndSealed(accumAddress_, packetId, signature_);
    }

    function challengeSignature(
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_,
        bytes calldata signature_
    ) external override {
        address attester = _getAttester(
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
        if (_remoteRoots[remoteChainId_][accumAddress_][packetId_] != 0)
            revert AlreadyProposed();

        _verifyAndUpdateAttestations(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );

        _remoteRoots[remoteChainId_][accumAddress_][packetId_] = root_;
        _timeRecord[accumAddress_][packetId_] = block.timestamp;
        emit Proposed(remoteChainId_, accumAddress_, packetId_, root_);
    }

    function confirmRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external {
        if (_isPaused[accumAddress_][packetId_]) revert PacketPaused();
        if (_remoteRoots[remoteChainId_][accumAddress_][packetId_] != root_)
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

    function pausePacketOnDest(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) external {
        if (_remoteRoots[remoteChainId_][accumAddress_][packetId_] != root_)
            revert RootNotFound();
        if (_isPaused[accumAddress_][packetId_]) revert PacketPaused();

        _isPaused[accumAddress_][packetId_] = true;

        emit PausedPacket(accumAddress_, packetId_, msg.sender);
    }

    function acceptPausedPacket(address accumAddress_, uint256 packetId_)
        external
        onlyOwner
    {
        if (!_isPaused[accumAddress_][packetId_]) revert PacketNotPaused();
        _isPaused[accumAddress_][packetId_] = false;
        emit PacketUnpaused(accumAddress_, packetId_);
    }

    function _getAttester(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) private returns (address attester) {
        bytes32 digest = keccak256(
            abi.encode(remoteChainId_, accumAddress_, packetId_, root_)
        );
        attester = _signatureVerifier.recoverSigner(digest, signature_);
    }

    function _verifyAndUpdateAttestations(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) private returns (address attester) {
        attester = _getAttester(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_,
            signature_
        );

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();

        if (_isAttested[attester][accumAddress_][packetId_])
            revert AlreadyAttested();

        _isAttested[attester][accumAddress_][packetId_] = true;
        _attestations[accumAddress_][packetId_]++;
    }

    function grantAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        if (_hasRole(_attesterRole(remoteChainId_), attester_))
            revert AttesterExists();
        _grantRole(_attesterRole(remoteChainId_), attester_);
        _totalAttestors[remoteChainId_]++;
    }

    function revokeAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        if (!_hasRole(_attesterRole(remoteChainId_), attester_))
            revert AttesterNotFound();
        _revokeRole(_attesterRole(remoteChainId_), attester_);
        _totalAttestors[remoteChainId_]--;
    }

    function _setSignatureVerifier(address signatureVerifier_) private {
        _signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    function _attesterRole(uint256 chainId_) internal pure returns (bytes32) {
        return bytes32(chainId_);
    }

    function getAccumDetails(address accumAddress_)
        external
        view
        returns (AccumDetails memory)
    {
        return _accumDetails[accumAddress_];
    }

    function isAttested(address accumAddress_, uint256 packetId_)
        external
        view
        returns (bool)
    {
        PacketStatus status = getPacketStatus(accumAddress_, packetId_);

        if (status == PacketStatus.CONFIRMED) return true;
        return false;
    }

    function getPacketStatus(address accumAddress_, uint256 packetId_)
        public
        view
        returns (PacketStatus status)
    {
        uint256 packetArrivedAt = _timeRecord[accumAddress_][packetId_];
        if (packetArrivedAt == 0) return PacketStatus.NOT_PROPOSED;

        uint256 remoteChainId = _accumDetails[accumAddress_].remoteChainId;

        // if timed out
        if (block.timestamp - packetArrivedAt > _timeoutInSeconds)
            return PacketStatus.TIMED_OUT;

        // if paused at dest
        if (_isPaused[accumAddress_][packetId_]) return PacketStatus.PAUSED;

        // if not 100% confirmed for fast path or consider wait time for slow path
        if (_accumDetails[accumAddress_].isFast) {
            if (
                _attestations[accumAddress_][packetId_] !=
                _totalAttestors[remoteChainId]
            ) return PacketStatus.PROPOSED;
        } else {
            if (block.timestamp - packetArrivedAt < _timeoutInSeconds)
                return PacketStatus.PROPOSED;
        }

        return PacketStatus.CONFIRMED;
    }

    function signatureVerifier() external view returns (address) {
        return address(_signatureVerifier);
    }

    function getConfirmations(address accumAddress_, uint256 packetId_)
        external
        view
        returns (uint256)
    {
        return _attestations[accumAddress_][packetId_];
    }

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view override returns (bytes32) {
        return _remoteRoots[remoteChainId_][accumAddress_][packetId_];
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }
}
