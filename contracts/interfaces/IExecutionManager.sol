// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

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
     * @param minMsgGasLimit_ The gas limit for the transaction
     * @param payloadSize_ The gas limit for the transaction
     * @param executionParams_ The gas limit for the transaction
     * @param siblingChainSlug_ The gas limit for the transaction
     * @param switchboardFees_ The gas limit for the transaction
     * @param verificationFees_ The gas limit for the transaction
     * @param transmitManager_ The transmitManager address
     * @param switchboard_ The switchboard address
     * @param maxPacketLength_ The maxPacketLength for the capacitor
     */
    function payAndCheckFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        uint32 siblingChainSlug_,
        uint128 switchboardFees_,
        uint128 verificationFees_,
        address transmitManager_,
        address switchboard_,
        uint256 maxPacketLength_
    ) external payable returns (uint128, uint128);

    /**
     * @notice Returns the minimum fees required for executing a transaction on the external chain
     * @param minMsgGasLimit_ minMsgGasLimit_
     * @param siblingChainSlug_ The destination slug
     * @return The minimum fees required for executing the transaction
     */
    function getMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_
    ) external view returns (uint128);

    function getExecutionTransmissionMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 siblingChainSlug_,
        address transmitManager_
    ) external view returns (uint128, uint128);

    /**
     * @notice Updates the execution fees for an executor and message ID
     * @param executor The executor address
     * @param executionFees The execution fees to update
     * @param msgId The ID of the message
     */
    function updateExecutionFees(
        address executor,
        uint128 executionFees,
        bytes32 msgId
    ) external;

    function updateTransmissionMinFees(
        uint32 remoteChainSlug_,
        uint128 transmitMinFees_
    ) external;

    function setExecutionFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint128 executionFees_,
        bytes calldata signature_
    ) external;

    function setMsgValueMinThreshold(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 msgValueMinThreshold_,
        bytes calldata signature_
    ) external;

    function setMsgValueMaxThreshold(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 msgValueMaxThreshold_,
        bytes calldata signature_
    ) external;

    function setRelativeNativeTokenPrice(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint256 relativeNativeTokenPrice_,
        bytes calldata signature_
    ) external;

    function verifyParams(
        bytes32 executionParams_,
        uint256 msgValue_
    ) external view;

    function withdrawSwitchboardFees(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external;

    function withdrawTransmissionFees(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external;
}
