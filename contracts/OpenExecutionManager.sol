// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./utils/AccessControlExtended.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/SignatureVerifierLib.sol";
import "./libraries/FeesHelper.sol";
import "./libraries/SignatureVerifierLib.sol";
import {WITHDRAW_ROLE, RESCUE_ROLE, GOVERNANCE_ROLE, EXECUTOR_ROLE, FEES_UPDATER_ROLE} from "./utils/AccessRoles.sol";
import {FEES_UPDATE_SIG_IDENTIFIER} from "./utils/SigIdentifiers.sol";

/**
 * @title OpenExecutionManager
 * @dev Implementation of the IExecutionManager interface, providing functions for executing cross-chain transactions and
 * managing execution fees. This contract also implements the AccessControlExtended interface, allowing for role-based
 * access control.
 */
contract OpenExecutionManager is IExecutionManager, AccessControlExtended {
    ISignatureVerifier public immutable signatureVerifier__;

    /**
     * @notice Emitted when the executionFees is updated
     * @param dstChainSlug The destination chain slug for which the executionFees is updated
     * @param executionFees The new executionFees
     */
    event ExecutionFeesSet(uint256 dstChainSlug, uint256 executionFees);

    uint32 public immutable chainSlug;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    // remoteChainSlug => executionFees
    mapping(uint32 => uint256) public executionFees;

    error InvalidNonce();

    /**
     * @dev Constructor for OpenExecutionManager contract
     * @param owner_ Address of the contract owner
     */
    constructor(
        address owner_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_
    ) AccessControlExtended(owner_) {
        signatureVerifier__ = signatureVerifier_;
        chainSlug = chainSlug_;
    }

    /**
     * @notice this function is open for execution
     * @param packedMessage Packed message to be executed
     * @param sig Signature of the message
     * @return executor Address of the executor
     * @return isValidExecutor Boolean value indicating whether the executor is valid or not
     */
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external pure override returns (address executor, bool isValidExecutor) {
        executor = SignatureVerifierLib.recoverSignerFromDigest(
            packedMessage,
            sig
        );
        isValidExecutor = true; //_hasRole(EXECUTOR_ROLE, executor);
    }

    /**
     * @dev Function to be used for on-chain fee distribution later
     */
    function updateExecutionFees(address, uint256, bytes32) external override {}

    /**
     * @notice Function for paying fees for cross-chain transaction execution
     * @param msgGasLimit_ Gas limit for the transaction
     * @param siblingChainSlug_ Sibling chain identifier
     */
    function payFees(
        uint256 msgGasLimit_,
        uint32 siblingChainSlug_
    ) external payable override {}

    /**
     * @notice Function for getting the minimum fees required for executing a cross-chain transaction
     * @dev This function is called at source to calculate the execution cost.
     * @param siblingChainSlug_ Sibling chain identifier
     * @return Minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256,
        uint32 siblingChainSlug_
    ) external view override returns (uint256) {
        return executionFees[siblingChainSlug_];
    }

    function setExecutionFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 executionFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    executionFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);

        uint256 nonce = nextNonce[feesUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        executionFees[dstChainSlug_] = executionFees_;
        emit ExecutionFeesSet(dstChainSlug_, executionFees_);
    }

    /**
     * @notice withdraws fees from contract
     * @param account_ withdraw fees to
     */
    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        FeesHelper.withdrawFees(account_);
    }

    /**
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
