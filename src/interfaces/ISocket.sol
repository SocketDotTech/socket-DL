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
        uint256 indexed packetId,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
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

    event MessageTransmitted(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 nonce,
        bytes payload
    );

    error InvalidBondReduce();

    error UnbondInProgress();

    error ClaimTimeLeft();

    error InvalidBond();

    error InvalidSigner();

    error InvalidRemotePlug();

    error InvalidProof();

    error DappVerificationFailed();

    error RemoteRootAlreadySubmitted();

    error MessageAlreadyExecuted();

    error InvalidNonce();

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
        uint256 packetId_
    ) external;

    function submitRemoteRoot(
        uint8 sigV_,
        bytes32 sigR_,
        bytes32 sigS_,
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_
    ) external;

    function outbound(uint256 remoteChainId, bytes calldata payload) external;

    function execute(
        uint256 remoteChainId_,
        address localPlug_,
        uint256 nonce,
        address signer_,
        address remoteAccum_,
        uint256 packetId_,
        bytes calldata payload_,
        bytes calldata deaccumProof_
    ) external;

    // TODO: add confs and blocking/non-blocking
    struct InboundConfig {
        address remotePlug;
        address deaccum;
        address verifier;
        bool isSequential;
    }

    struct OutboundConfig {
        address accum;
        address remotePlug;
    }

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_,
        bool isSequential_
    ) external;

    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external;

    function grantSignerRole(uint256 remoteChainId_, address signer_) external;

    function revokeSignerRole(uint256 remoteChainId_, address signer_) external;

    function getRemoteRoot(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_
    ) external view returns (bytes32);
}
