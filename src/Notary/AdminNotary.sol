// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/INotary.sol";
import "../utils/AccessControl.sol";
import "../interfaces/IAccumulator.sol";

contract Notary is INotary, AccessControl(msg.sender) {
    uint256 private immutable _chainId;

    // attester => accumAddress => packetId => sig hash
    mapping(address => mapping(address => mapping(uint256 => bytes32)))
        private _localSignatures;

    // remoteChainId => accumAddress => packetId => root
    mapping(uint256 => mapping(address => mapping(uint256 => bytes32)))
        private _remoteRoots;

    // attester => accumAddress => packetId => is attested
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private _isAttested;

    // accumAddress => packetId => total attestations
    mapping(address => mapping(uint256 => uint256)) public _attestations;

    // accumAddress => packetId => bool (is paused)
    mapping(address => mapping(uint256 => bool)) public _isChallenged;

    struct AccumDetails {
        uint256 remoteChainId;
        bool isFast;
    }

    uint256 private _totalAttestors;
    mapping(address => uint256) private _attestorList;

    mapping(address => AccumDetails) private _accumDetails;

    error Restricted();

    error AccumAlreadyAdded();

    error AlreadyAttested();

    error NotFastPath();

    error PacketChallenged();

    error PacketNotChallenged();

    constructor(uint256 chainId_) {
        _chainId = chainId_;
    }

    function addBond() external payable override {
        revert Restricted();
    }

    function reduceBond(uint256 amount) external override {
        revert Restricted();
    }

    function unbondAttester() external override {
        revert Restricted();
    }

    function claimBond() external override {
        revert Restricted();
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

    function getAccumDetails(address accumAddress_)
        external
        view
        returns (AccumDetails memory)
    {
        return _accumDetails[accumAddress_];
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function isAttested(address accumAddress_, uint256 packetId_)
        external
        view
        returns (bool)
    {
        // if not 100% confirmed for fast path
        if (_accumDetails[accumAddress_].isFast) {
            if (_attestations[accumAddress_][packetId_] != _totalAttestors)
                return false;
        }

        // if challenged
        if (_isChallenged[accumAddress_][packetId_]) return false;

        return true;
    }

    function submitSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_
    ) external override {
        (bytes32 root, uint256 packetId) = IAccumulator(accumAddress_)
            .sealPacket();

        address attester = _getAttester(
            sigV_,
            sigR_,
            sigS_,
            _chainId,
            accumAddress_,
            packetId,
            root
        );

        if (
            !_hasRole(
                _attesterRole(_accumDetails[accumAddress_].remoteChainId),
                attester
            )
        ) revert InvalidAttester();

        emit SignatureSubmitted(accumAddress_, packetId, sigV_, sigR_, sigS_);
    }

    function challengeSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_
    ) external override {
        bytes32 digest = keccak256(
            abi.encode(_chainId, accumAddress_, packetId_, root_)
        );
        address attester = ecrecover(digest, sigV_, sigR_, sigS_);
        bytes32 oldSig = _localSignatures[attester][accumAddress_][packetId_];

        if (oldSig != keccak256(abi.encode(sigV_, sigR_, sigS_))) {
            emit ChallengedSuccessfully(
                attester,
                accumAddress_,
                packetId_,
                msg.sender,
                0
            );
        }
    }

    function submitRemoteRoot(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) external override {
        if (_remoteRoots[remoteChainId_][accumAddress_][packetId_] != 0)
            revert RemoteRootAlreadySubmitted();

        _verifyAndUpdateAttestations(
            sigV_,
            sigR_,
            sigS_,
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );

        _remoteRoots[remoteChainId_][accumAddress_][packetId_] = root_;
        emit RemoteRootSubmitted(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );
    }

    function confirmRoot(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) external {
        if (!_accumDetails[accumAddress_].isFast) revert NotFastPath();
        if (_isChallenged[accumAddress_][packetId_]) revert PacketChallenged();

        address attester = _verifyAndUpdateAttestations(
            sigV_,
            sigR_,
            sigS_,
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );

        emit RootConfirmed(attester, accumAddress_, packetId_);
    }

    function challengePacketOnDest(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) external {
        if (_isChallenged[accumAddress_][packetId_]) revert PacketChallenged();
        address attester = _getAttester(
            sigV_,
            sigR_,
            sigS_,
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );

        bytes32 root = IAccumulator(accumAddress_).getRootById(packetId_);

        if (root == root_) {
            _isChallenged[accumAddress_][packetId_] = true;

            emit PacketChallengedOnDest(
                attester,
                accumAddress_,
                packetId_,
                msg.sender
            );
        }
    }

    function acceptChallengedPacket(address accumAddress_, uint256 packetId_)
        external
        onlyOwner
    {
        if (!_isChallenged[accumAddress_][packetId_])
            revert PacketNotChallenged();
        _isChallenged[accumAddress_][packetId_] = false;
        emit RevertChallengedPacket(accumAddress_, packetId_);
    }

    function _getAttester(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) private pure returns (address attester) {
        bytes32 digest = keccak256(
            abi.encode(remoteChainId_, accumAddress_, packetId_, root_)
        );
        attester = ecrecover(digest, sigV_, sigR_, sigS_);
    }

    function _verifyAndUpdateAttestations(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) private returns (address attester) {
        attester = _getAttester(
            sigV_,
            sigR_,
            sigS_,
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();

        if (_isAttested[attester][accumAddress_][packetId_])
            revert AlreadyAttested();

        _isAttested[attester][accumAddress_][packetId_] = true;
        _attestations[accumAddress_][packetId_]++;
    }

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view override returns (bytes32) {
        return _remoteRoots[remoteChainId_][accumAddress_][packetId_];
    }

    function grantAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        _totalAttestors++;
        _attestorList[attester_] = _totalAttestors;

        _grantRole(_attesterRole(remoteChainId_), attester_);
    }

    function revokeAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        _attestorList[attester_] = 0;
        _totalAttestors--;

        _revokeRole(_attesterRole(remoteChainId_), attester_);
    }

    function _attesterRole(uint256 remoteChainId_)
        private
        pure
        returns (bytes32)
    {
        return bytes32(remoteChainId_);
    }
}
