// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

/**
 * @title Execution Manager Interface
 * @dev This interface defines the functions for managing and executing transactions on external chains
 */
interface IExecutionManager {
    /**
     * @notice Returns the executor of the packed message and whether the executor is authorized
     * @param packedMessage The message packed with payload, fees and config
     * @param sig The signature of the message
     * @return The address of the executor and a boolean indicating if the executor is authorized
     */
    function isExecutor(
        bytes32 packedMessage,
        bytes memory sig
    ) external view returns (address, bool);

    /**
     * @notice Pays the fees for executing a transaction on the external chain
     * @dev This function is payable and assumes the socket is going to send correct amount of fees.
     * @param msgGasLimit The gas limit for the transaction
     * @param dstSlug The destination slug
     */
    function payFees(uint256 msgGasLimit, uint32 dstSlug) external payable;

    /**
     * @notice Returns the minimum fees required for executing a transaction on the external chain
     * @param msgGasLimit The gas limit for the transaction
     * @param dstSlug The destination slug
     * @return The minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256 msgGasLimit,
        uint32 dstSlug
    ) external view returns (uint256);

    /**
     * @notice Updates the execution fees for an executor and message ID
     * @param executor The executor address
     * @param executionFees The execution fees to update
     * @param msgId The ID of the message
     */
    function updateExecutionFees(
        address executor,
        uint256 executionFees,
        bytes32 msgId
    ) external;
}
