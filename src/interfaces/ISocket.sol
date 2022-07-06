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

    error InvalidBondReduce();

    error UnbondInProgress();

    error ClaimTimeLeft();

    error InvalidBond();

    function addBond() external payable;

    function reduceBond(uint256 amount) external;

    function unbondSigner() external;

    function claimBond() external;

    function submitSignature(
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        address accumAddress
    ) external;

    function outbound(uint256 remoteChainId, bytes calldata payload) external;

    // TODO: add confs and blocking/non-blocking
    struct InboundConfig {
        address accumulator;
        address verifier;
        address remotePlug;
    }

    struct OutboundConfig {
        address accumulator;
        address verifier;
        address remotePlug;
    }

    function setInboundConfig(
        uint256 remoteChainId,
        address accumulator,
        address verifier,
        address remotePlug
    ) external;

    function setOutboundConfig(
        uint256 remoteChainId,
        address accumulator,
        address verifier,
        address remotePlug
    ) external;
}
