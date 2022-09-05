// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface INotary {
    event SignatureVerifierSet(address verifier);

    event PacketVerifiedAndSealed(
        address indexed accumAddress,
        uint256 indexed packetId,
        bytes signature
    );

    event Proposed(
        uint256 indexed remoteChainId,
        address indexed accumAddress,
        uint256 indexed packetId,
        bytes32 root
    );

    event ChallengedSuccessfully(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId,
        address challenger,
        uint256 rewardAmount
    );

    event PacketUnpaused(
        address indexed accumAddress,
        uint256 indexed packetId
    );

    event PacketPaused(
        address indexed accumAddress,
        uint256 indexed packetId,
        address challenger
    );

    event RootConfirmed(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId
    );

    error InvalidAttester();

    error AlreadyProposed();

    function verifyAndSeal(address accumAddress_, bytes calldata signature_)
        external;

    function challengeSignature(
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_,
        bytes calldata signature_
    ) external;

    function propose(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external;

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view returns (bytes32);

    function isAttested(address accumAddress_, uint256 packetId_)
        external
        view
        returns (bool);
}
