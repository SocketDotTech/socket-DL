// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISocket {
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

    event SignatureSubmitted(
        address indexed accumAddress,
        uint256 indexed batchId,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    );

    event RemoteRootSubmitted(
        uint256 indexed remoteChainId,
        address indexed accumAddress,
        uint256 indexed batchId,
        bytes32 root
    );

    event SignatureChallenged(
        address indexed signer,
        address indexed accumAddress,
        uint256 indexed batchId,
        address challenger,
        uint256 rewardAmount
    );

    error InvalidBondReduce();

    error UnbondInProgress();

    error ClaimTimeLeft();

    error InvalidBond();

    error InvalidSigner();

    function addBond() external payable;

    function reduceBond(uint256 amount) external;

    function unbondSigner() external;

    function claimBond() external;

    function submitSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_
    ) external;

    function challengeSignature(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        address accumAddress_,
        bytes32 root_,
        uint256 batchId_
    ) external;

    function outbound(uint256 remoteChainId, bytes calldata payload) external;

    // TODO: add confs and blocking/non-blocking
    struct InboundConfig {
        address remotePlug;
        address signer;
        address deaccum;
        address verifier;
    }

    struct OutboundConfig {
        address accum;
        address remotePlug;
    }

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address signer_,
        address deaccum_,
        address verifier_
    ) external;

    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external;
}
