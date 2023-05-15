// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./interfaces/IGasPriceOracle.sol";
import "./utils/AccessControl.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/SignatureVerifierLib.sol";
import "./libraries/FeesHelper.sol";
import "./utils/AccessControlExtended.sol";
import {WITHDRAW_ROLE, RESCUE_ROLE, GOVERNANCE_ROLE, EXECUTOR_ROLE, FEES_UPDATER_ROLE} from "./utils/AccessRoles.sol";
import {FEES_UPDATE_SIG_IDENTIFIER} from "./utils/SigIdentifiers.sol";

/**
 * @title ExecutionManager
 * @dev Implementation of the IExecutionManager interface, providing functions for executing cross-chain transactions and
 * managing execution fees. This contract also implements the AccessControl interface, allowing for role-based
 * access control.
 */
contract ExecutionManager is IExecutionManager, AccessControlExtended {
    ISignatureVerifier public signatureVerifier__;
    IGasPriceOracle public gasPriceOracle__;
    event GasPriceOracleSet(address gasPriceOracle);

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
     * @dev Constructor for ExecutionManager contract
     * @param gasPriceOracle_ Address of the Gas Price Oracle contract
     * @param owner_ Address of the contract owner
     * @param chainSlug_ The chain slug of the current contract
     */
    constructor(
        IGasPriceOracle gasPriceOracle_,
        address owner_,
        uint32 chainSlug_,
        ISignatureVerifier signatureVerifier_
    ) AccessControlExtended(owner_) {
        chainSlug = chainSlug_;
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        signatureVerifier__ = signatureVerifier_;
    }

    /**
     * @notice Checks whether the provided signer address is an executor for the given packed message and signature
     * @param packedMessage Packed message to be executed
     * @param sig Signature of the message
     * @return executor Address of the executor
     * @return isValidExecutor Boolean value indicating whether the executor is valid or not
     */
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view override returns (address executor, bool isValidExecutor) {
        executor = SignatureVerifierLib.recoverSignerFromDigest(
            packedMessage,
            sig
        );
        isValidExecutor = _hasRole(EXECUTOR_ROLE, executor);
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
        uint32 siblingChainSlug_
    ) external view override returns (uint256) {
        return executionFees[siblingChainSlug_];
    }

    /**
     * @dev Function for getting the minimum fees required for executing a cross-chain transaction
     * @param msgGasLimit_ Gas limit for the transaction
     * @param dstChainSlug_ Destination chain identifier
     * @return Minimum fees required for executing the transaction
     */
    function _getMinExecutionFees(
        uint256 msgGasLimit_,
        uint32 dstChainSlug_
    ) internal view returns (uint256) {
        uint256 dstRelativeGasPrice = gasPriceOracle__.relativeGasPrice(
            dstChainSlug_
        );
        return msgGasLimit_ * dstRelativeGasPrice;
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
     * @notice updates gasPriceOracle__
     * @param gasPriceOracle_ address of Gas Price Oracle
     */
    function setGasPriceOracle(
        address gasPriceOracle_
    ) external onlyRole(GOVERNANCE_ROLE) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        emit GasPriceOracleSet(gasPriceOracle_);
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
