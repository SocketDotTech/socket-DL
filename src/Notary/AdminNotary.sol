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

    bytes32 public constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");

    error Restricted();

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

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function submitSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_
    ) external override onlyRole(ATTESTER_ROLE) {
        (bytes32 root, uint256 packetId) = IAccumulator(accumAddress_)
            .sealPacket();

        bytes32 digest = keccak256(
            abi.encode(_chainId, accumAddress_, packetId, root)
        );
        address attester = ecrecover(digest, sigV_, sigR_, sigS_);

        _localSignatures[attester][accumAddress_][packetId] = keccak256(
            abi.encode(sigV_, sigR_, sigS_)
        );

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
            uint256 bond = 0;
            payable(msg.sender).transfer(bond);
            emit ChallengedSuccessfully(
                attester,
                accumAddress_,
                packetId_,
                msg.sender,
                bond
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
        bytes32 digest = keccak256(
            abi.encode(remoteChainId_, accumAddress_, packetId_, root_)
        );
        address attester = ecrecover(digest, sigV_, sigR_, sigS_);

        if (!_hasRole(_attesterRole(remoteChainId_), attester))
            revert InvalidAttester();

        if (_remoteRoots[remoteChainId_][accumAddress_][packetId_] != 0)
            revert RemoteRootAlreadySubmitted();

        _remoteRoots[remoteChainId_][accumAddress_][packetId_] = root_;
        emit RemoteRootSubmitted(
            remoteChainId_,
            accumAddress_,
            packetId_,
            root_
        );
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
        _grantRole(_attesterRole(remoteChainId_), attester_);
    }

    function revokeAttesterRole(uint256 remoteChainId_, address attester_)
        external
        onlyOwner
    {
        _revokeRole(_attesterRole(remoteChainId_), attester_);
    }

    function _attesterRole(uint256 chainId_) internal pure returns (bytes32) {
        return bytes32(chainId_);
    }
}
