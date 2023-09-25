// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./ITransmitManager.sol";
import "./IExecutionManager.sol";

/**
 * @title ISocket
 * @notice An interface for a cross-chain communication contract
 * @dev This interface provides methods for transmitting and executing messages between chains,
 * connecting a plug to a remote chain and setting up switchboards for the message transmission
 * This interface also emits events for important operations such as message transmission, execution status,
 * and plug connection
 */
interface ISocket {
    /**
     * @notice A struct containing fees required for message transmission and execution
     * @param transmissionFees fees needed for transmission
     * @param switchboardFees fees needed by switchboard
     * @param executionFee fees needed for execution
     */
    struct Fees {
        uint128 transmissionFees;
        uint128 executionFee;
        uint128 switchboardFees;
    }

    /**
     * @title MessageDetails
     * @dev This struct defines the details of a message to be executed in a Decapacitor contract.
     */
    struct MessageDetails {
        // A unique identifier for the message.
        bytes32 msgId;
        // The fee to be paid for executing the message.
        uint256 executionFee;
        // The min amount of gas that can be used to execute the message.
        uint256 minMsgGasLimit;
        // The extra params which might provide msg value and additional info needed for message exec
        bytes32 executionParams;
        // The payload data to be executed in the message.
        bytes payload;
    }

    /**
     * @title ExecutionDetails
     * @dev This struct defines the execution details
     */
    struct ExecutionDetails {
        // packet id
        bytes32 packetId;
        // proposal count
        uint256 proposalCount;
        // gas limit needed to execute inbound
        uint256 executionGasLimit;
        // proof data required by the Decapacitor contract to verify the message's authenticity
        bytes decapacitorProof;
        // signature of executor
        bytes signature;
    }

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     */
    event ExecutionSuccess(bytes32 msgId);

    /**
     * @notice emits the config set by a plug for a remoteChainSlug
     * @param plug address of plug on current chain
     * @param siblingChainSlug sibling chain slug
     * @param siblingPlug address of plug on sibling chain
     * @param inboundSwitchboard inbound switchboard (select from registered options)
     * @param outboundSwitchboard outbound switchboard (select from registered options)
     * @param capacitor capacitor selected based on outbound switchboard
     * @param decapacitor decapacitor selected based on inbound switchboard
     */
    event PlugConnected(
        address plug,
        uint32 siblingChainSlug,
        address siblingPlug,
        address inboundSwitchboard,
        address outboundSwitchboard,
        address capacitor,
        address decapacitor
    );

    /**
     * @notice registers a message
     * @dev Packs the message and includes it in a packet with capacitor
     * @param remoteChainSlug_ the remote chain slug
     * @param minMsgGasLimit_ the gas limit needed to execute the payload on remote
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function outbound(
        uint32 remoteChainSlug_,
        uint256 minMsgGasLimit_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        bytes calldata payload_
    ) external payable returns (bytes32 msgId);

    /**
     * @notice executes a message
     * @param executionDetails_ the packet details, proof and signature needed for message execution
     * @param messageDetails_ the message details
     */
    function execute(
        ISocket.ExecutionDetails calldata executionDetails_,
        ISocket.MessageDetails calldata messageDetails_
    ) external payable;

    /**
     * @notice seals data in capacitor for specific batchSize
     * @param batchSize_ size of batch to be sealed
     * @param capacitorAddress_ address of capacitor
     * @param signature_ signed Data needed for verification
     */
    function seal(
        uint256 batchSize_,
        address capacitorAddress_,
        bytes calldata signature_
    ) external payable;

    /**
     * @notice proposes a packet
     * @param packetId_ packet id
     * @param root_ root data
     * @param switchboard_ The address of switchboard for which this packet is proposed
     * @param signature_ signed Data needed for verification
     */
    function proposeForSwitchboard(
        bytes32 packetId_,
        bytes32 root_,
        address switchboard_,
        bytes calldata signature_
    ) external payable;

    /**
     * @notice sets the config specific to the plug
     * @param siblingChainSlug_ the sibling chain slug
     * @param siblingPlug_ address of plug present at sibling chain to call inbound
     * @param inboundSwitchboard_ the address of switchboard to use for receiving messages
     * @param outboundSwitchboard_ the address of switchboard to use for sending messages
     */
    function connect(
        uint32 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external;

    /**
     * @notice deploy capacitor and decapacitor for a switchboard with a specified max packet length, sibling chain slug, and capacitor type.
     * @param siblingChainSlug_ The slug of the sibling chain that the switchboard is registered with.
     * @param maxPacketLength_ The maximum length of a packet allowed by the switchboard.
     * @param capacitorType_ The type of capacitor that the switchboard uses.
     * @param siblingSwitchboard_ The switchboard address deployed on `siblingChainSlug_`
     */
    function registerSwitchboardForSibling(
        uint32 siblingChainSlug_,
        uint256 maxPacketLength_,
        uint256 capacitorType_,
        address siblingSwitchboard_
    ) external returns (address capacitor, address decapacitor);

    /**
     * @notice Emits the sibling switchboard for given `siblingChainSlug_`.
     * @dev This function is expected to be only called by switchboard.
     * @dev the event emitted is tracked by transmitters to decide which switchboard a packet should be proposed on
     * @param siblingChainSlug_ The slug of the sibling chain
     * @param siblingSwitchboard_ The switchboard address deployed on `siblingChainSlug_`
     */
    function useSiblingSwitchboard(
        uint32 siblingChainSlug_,
        address siblingSwitchboard_
    ) external;

    /**
     * @notice Retrieves the packet id roots for a specified packet id.
     * @param packetId_ The packet id for which to retrieve the root.
     * @param proposalCount_ The proposal id for packetId_ for which to retrieve the root.
     * @param switchboard_ The address of switchboard for which this packet is proposed
     * @return The packet id roots for the specified packet id.
     */
    function packetIdRoots(
        bytes32 packetId_,
        uint256 proposalCount_,
        address switchboard_
    ) external view returns (bytes32);

    /**
     * @notice Retrieves the latest proposalCount for a packet id.
     * @return The proposal count for the specified packet id.
     */
    function proposalCount(bytes32 packetId_) external view returns (uint256);

    /**
     * @notice Retrieves the minimum fees required for a message with a specified gas limit and destination chain.
     * @param minMsgGasLimit_ The gas limit of the message.
     * @param remoteChainSlug_ The slug of the destination chain for the message.
     * @param plug_ The address of the plug through which the message is sent.
     * @return totalFees The minimum fees required for the specified message.
     */
    function getMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        uint32 remoteChainSlug_,
        address plug_
    ) external view returns (uint256 totalFees);

    /// return instance of transmit manager
    function transmitManager__() external view returns (ITransmitManager);

    /// return instance of execution manager
    function executionManager__() external view returns (IExecutionManager);
}
