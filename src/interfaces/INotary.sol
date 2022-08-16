// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface INotary {
    event BondAdded(
        address indexed signer,
        uint256 addAmount, // assuming native token
        uint256 newBond
    );

    event BondReduced(
        address indexed signer,
        uint256 reduceAmount,
        uint256 newBond
    );

    event Unbonded(address indexed signer, uint256 amount, uint256 claimTime);

    event BondClaimed(address indexed signer, uint256 amount);

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
        address indexed signer,
        address indexed accumAddress,
        uint256 indexed packetId,
        address challenger,
        uint256 rewardAmount
    );

    error InvalidBondReduce();

    error UnbondInProgress();

    error ClaimTimeLeft();

    error InvalidBond();

    error InvalidSigner();

    error RemoteRootAlreadySubmitted();

    function addBond() external payable;

    function reduceBond(uint256 amount) external;

    function unbondSigner() external;

    function claimBond() external;

    function submitSignature(address accumAddress_, bytes memory signature)
        external;

    function challengeSignature(
        address accumAddress_,
        bytes32 root_,
        uint256 packetId_,
        bytes memory signature
    ) external;

    function submitRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes memory signature
    ) external;

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view returns (bytes32);
}
