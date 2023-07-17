// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

/**
 * @title Execution Manager Interface
 * @dev This interface defines the functions for managing and executing transactions on external chains
 * @dev It is also responsible for collecting all the socket fees, which can then be pulled by others
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
     * @param minMsgGasLimit_ The minimum gas limit for the transaction
     * @param payloadSize_ The payload size in bytes
     * @param executionParams_ Extra params for execution
     * @param transmissionParams_ Extra params for transmission
     * @param siblingChainSlug_ Sibling chain identifier
     * @param switchboardFees_ fee charged by switchboard for processing transaction
     * @param verificationOverheadFees_ fee charged for verifying transaction
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
        uint128 verificationOverheadFees_,
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

    /**
     * @notice function for getting the minimum fees required for executing and transmitting a cross-chain transaction
     * @dev this function is called at source to calculate the execution cost.
     * @param payloadSize_ byte length of payload. Currently only used to check max length, later on will be used for fees calculation.
     * @param executionParams_ Can be used for providing extra information. Currently used for msgValue
     * @param siblingChainSlug_ Sibling chain identifier
     * @return minExecutionFee : Minimum fees required for executing the transaction
     */
    function getExecutionTransmissionMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
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

    /**
     * @notice updates the transmission fee
     * @param remoteChainSlug_ sibling chain identifier
     * @param transmitMinFees_ transmission fees collected
     */
    function setTransmissionMinFees(
        uint32 remoteChainSlug_,
        uint128 transmitMinFees_
    ) external;

    /**
     * @notice sets the minimum execution fees required for executing at `siblingChainSlug_`
     * @dev this function currently sets the price for a constant msg gas limit and payload size
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param executionFees_ total fees where price in destination native token is converted to source native tokens
     * @param signature_ signature of fee updater
     */
    function setExecutionFees(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint128 executionFees_,
        bytes calldata signature_
    ) external;

    /**
     * @notice sets the min limit for msg value for `siblingChainSlug_`
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param msgValueMinThreshold_ min msg value
     * @param signature_ signature of fee updater
     */
    function setMsgValueMinThreshold(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint256 msgValueMinThreshold_,
        bytes calldata signature_
    ) external;

    /**
     * @notice sets the max limit for msg value for `siblingChainSlug_`
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param msgValueMaxThreshold_ max msg value
     * @param signature_ signature of fee updater
     */
    function setMsgValueMaxThreshold(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint256 msgValueMaxThreshold_,
        bytes calldata signature_
    ) external;

    /**
     * @notice sets the relative token price for `siblingChainSlug_`
     * @dev this function is expected to be called frequently to match the original prices
     * @param nonce_ incremental id to prevent signature replay
     * @param siblingChainSlug_ sibling chain identifier
     * @param relativeNativeTokenPrice_ relative price
     * @param signature_ signature of fee updater
     */
    function setRelativeNativeTokenPrice(
        uint256 nonce_,
        uint32 siblingChainSlug_,
        uint256 relativeNativeTokenPrice_,
        bytes calldata signature_
    ) external;

    /**
     * @notice called by socket while executing message to validate if the msg value provided is enough
     * @param executionParams_ a bytes32 string where first byte gives param type (if value is 0 or not)
     * and remaining bytes give the msg value needed
     * @param msgValue_ msg.value to be sent with inbound
     */
    function verifyParams(
        bytes32 executionParams_,
        uint256 msgValue_
    ) external view;

    /**
     * @notice withdraws switchboard fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     */
    function withdrawSwitchboardFees(
        uint32 siblingChainSlug_,
        address switchboard_,
        uint128 amount_
    ) external;

    /**
     * @dev this function gets the transmitManager address from the socket contract. If it is ever upgraded in socket,
     * @dev remove the fees from executionManager first, and then upgrade address at socket.
     * @notice withdraws transmission fees from contract
     * @param siblingChainSlug_ withdraw fees corresponding to this slug
     * @param amount_ withdraw amount
     */
    function withdrawTransmissionFees(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external;
}
