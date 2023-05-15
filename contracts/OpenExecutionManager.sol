// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IExecutionManager.sol";
import "./interfaces/IGasPriceOracle.sol";
import "./utils/AccessControlExtended.sol";
import "./libraries/RescueFundsLib.sol";
import "./libraries/SignatureVerifierLib.sol";
import "./libraries/FeesHelper.sol";
import {WITHDRAW_ROLE, RESCUE_ROLE, GOVERNANCE_ROLE, EXECUTOR_ROLE} from "./utils/AccessRoles.sol";

/**
 * @title OpenExecutionManager
 * @dev Implementation of the IExecutionManager interface, providing functions for executing cross-chain transactions and
 * managing execution fees. This contract also implements the AccessControlExtended interface, allowing for role-based
 * access control.
 */
contract OpenExecutionManager is IExecutionManager, AccessControlExtended {
    IGasPriceOracle public gasPriceOracle__;
    event GasPriceOracleSet(address gasPriceOracle);

    /**
     * @dev Constructor for OpenExecutionManager contract
     * @param gasPriceOracle_ Address of the Gas Price Oracle contract
     * @param owner_ Address of the contract owner
     */
    constructor(
        IGasPriceOracle gasPriceOracle_,
        address owner_
    ) AccessControlExtended(owner_) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
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
     * @param msgGasLimit_ Gas limit for the transaction
     * @param siblingChainSlug_ Sibling chain identifier
     * @return Minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256 msgGasLimit_,
        uint32 siblingChainSlug_
    ) external view override returns (uint256) {
        return _getMinExecutionFees(msgGasLimit_, siblingChainSlug_);
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
