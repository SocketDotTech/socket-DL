// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface INotary {
    event BondAdded(
        address indexed attester,
        uint256 addAmount, // assuming native token
        uint256 newBond
    );

    event BondReduced(
        address indexed attester,
        uint256 reduceAmount,
        uint256 newBond
    );

    event Unbonded(address indexed attester, uint256 amount, uint256 claimTime);

    event BondClaimed(address indexed attester, uint256 amount);

    event BondClaimDelaySet(uint256 delay);

    event MinBondAmountSet(uint256 amount);

    event SignatureVerifierSet(address verifier);

    event SignatureSubmitted(
        address indexed accumAddress,
        uint256 indexed packetId,
        bytes signature
    );

    event RemoteRootSubmitted(
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

    event RevertChallengedPacket(
        address indexed accumAddress,
        uint256 indexed packetId
    );

    event PacketChallengedOnDest(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId,
        address challenger
    );

    event RootConfirmed(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId
    );

    error InvalidBondReduce();

    error UnbondInProgress();

    error ClaimTimeLeft();

    error InvalidBond();

    error InvalidAttester();

    error RemoteRootAlreadySubmitted();

    function addBond() external payable;

    function reduceBond(uint256 amount) external;

    function unbondAttester() external;

    function claimBond() external;

    function submitSignature(address accumAddress_, bytes calldata signature_)
        external;

    function challengeSignature(
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_,
        bytes calldata signature_
    ) external;

    function submitRemoteRoot(
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
