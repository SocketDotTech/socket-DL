// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../interfaces/IPlug.sol";
import "./SocketBase.sol";
import {SOCKET_RELAYER_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketBase and
 * provides functionality for message execution, packet proposal, and verification.
 * It manages the mapping of message execution status, packet ID roots, and root proposed
 * timestamps. It emits events for packet proposal and root updates.
 * It also includes functions for message execution and verification
 */
abstract contract SocketDst is SocketBase {
    ////////////////////////////////////////////////////////
    ////////////////////// ERRORS //////////////////////////
    ////////////////////////////////////////////////////////

    /*
     * @dev Error emitted when a packet has not been proposed
     */
    error PacketNotProposed();
    /*
     * @dev Error emitted when a packet id is invalid
     */
    error InvalidPacketId();

    /**
     * @dev Error emitted when proof is invalid
     */
    error InvalidProof();

    /**
     * @dev Error emitted when a message has already been executed
     */
    error MessageAlreadyExecuted();
    /**
     * @dev Error emitted when the executor is not valid
     */
    error NotExecutor();
    /**
     * @dev Error emitted when verification fails
     */
    error VerificationFailed();
    /**
     * @dev Error emitted when source slugs deduced from packet id and msg id don't match
     */
    error ErrInSourceValidation();
    /**
     * @dev Error emitted when less gas limit is provided for execution than expected
     */
    error LowGasLimit();

    ////////////////////////////////////////////////////////////
    ////////////////////// State Vars //////////////////////////
    ////////////////////////////////////////////////////////////

    /**
     * @dev keeps track of whether a message has been executed or not using message id
     */
    mapping(bytes32 => bool) public messageExecuted;

    /**
     * @dev capacitorAddr|chainSlug|packetId => proposalCount => switchboard => packetIdRoots
     */
    mapping(bytes32 => mapping(uint256 => mapping(address => bytes32)))
        public
        override packetIdRoots;
    /**
     * @dev packetId => proposalCount => switchboard => proposalTimestamp
     */
    mapping(bytes32 => mapping(uint256 => mapping(address => uint256)))
        public rootProposedAt;

    /**
     * @dev packetId => proposalCount
     */
    mapping(bytes32 => uint256) public proposalCount;

    ////////////////////////////////////////////////////////
    ////////////////////// EVENTS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @notice emits the packet details when proposed at remote
     * @param transmitter address of transmitter
     * @param packetId packet id
     * @param proposalCount proposal id
     * @param root packet root
     */
    event PacketProposed(
        address indexed transmitter,
        bytes32 indexed packetId,
        uint256 proposalCount,
        bytes32 root,
        address switchboard
    );

    ////////////////////////////////////////////////////////
    ////////////////////// OPERATIONS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @dev Function to propose a packet
     * @notice the signature is validated if it belongs to transmitter or not
     * @param packetId_ packet id
     * @param root_ packet root
     * @param switchboard_ The address of switchboard for which this packet is proposed
     * @param signature_ signature
     */
    function proposeForSwitchboard(
        bytes32 packetId_,
        bytes32 root_,
        address switchboard_,
        bytes calldata signature_
    ) external payable override {
        if (!_hasRole(SOCKET_RELAYER_ROLE, msg.sender)) revert NoPermit(SOCKET_RELAYER_ROLE);

        if (packetId_ == bytes32(0)) revert InvalidPacketId();

        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                _decodeChainSlug(packetId_),
                keccak256(abi.encode(version, chainSlug, packetId_, root_)),
                signature_
            );

        if (!isTransmitter) revert InvalidTransmitter();

        packetIdRoots[packetId_][proposalCount[packetId_]][
            switchboard_
        ] = root_;
        rootProposedAt[packetId_][proposalCount[packetId_]][
            switchboard_
        ] = block.timestamp;

        emit PacketProposed(
            transmitter,
            packetId_,
            proposalCount[packetId_]++,
            root_,
            switchboard_
        );
    }

    /**
     * @notice Executes a message that has been delivered by transmitters and authenticated by switchboards
     * @param executionDetails_ all inputs needed from the executor for executing this particular message
     * @param messageDetails_ the details needed for message verification
     */
    function execute(
        ISocket.ExecutionDetails calldata executionDetails_,
        ISocket.MessageDetails calldata messageDetails_
    ) external payable override {
        if (!_hasRole(SOCKET_RELAYER_ROLE, msg.sender)) revert NoPermit(SOCKET_RELAYER_ROLE);

        // make sure message is not executed already
        if (messageExecuted[messageDetails_.msgId])
            revert MessageAlreadyExecuted();

        // update state to make sure no reentrancy
        messageExecuted[messageDetails_.msgId] = true;

        // make sure caller is calling with right gas limits
        // we also make sure to give executors the ability to execute with higher gas limits
        // than the minimum required
        if (
            executionDetails_.executionGasLimit < messageDetails_.minMsgGasLimit
        ) revert LowGasLimit();

        if (executionDetails_.packetId == bytes32(0)) revert InvalidPacketId();

        // extract chain slug from msgID
        uint32 remoteSlug = _decodeChainSlug(messageDetails_.msgId);

        // make sure packet and msg are for the same chain
        if (_decodeChainSlug(executionDetails_.packetId) != remoteSlug)
            revert ErrInSourceValidation();

        // extract plug address from msgID
        address localPlug = _decodePlug(messageDetails_.msgId);

        // fetch required vars from plug config
        PlugConfig memory plugConfig;
        plugConfig.decapacitor__ = _plugConfigs[localPlug][remoteSlug]
            .decapacitor__;
        plugConfig.siblingPlug = _plugConfigs[localPlug][remoteSlug]
            .siblingPlug;
        plugConfig.inboundSwitchboard__ = _plugConfigs[localPlug][remoteSlug]
            .inboundSwitchboard__;

        // fetch packet root
        bytes32 packetRoot = packetIdRoots[executionDetails_.packetId][
            executionDetails_.proposalCount
        ][address(plugConfig.inboundSwitchboard__)];
        if (packetRoot == bytes32(0)) revert PacketNotProposed();

        // create packed message
        bytes32 packedMessage = hasher__.packMessage(
            remoteSlug,
            plugConfig.siblingPlug,
            chainSlug,
            localPlug,
            messageDetails_
        );

        // make sure caller is executor
        (address executor, bool isValidExecutor) = executionManager__
            .isExecutor(packedMessage, executionDetails_.signature);
        if (!isValidExecutor) revert NotExecutor();

        // finally make sure executor params were respected by the executor
        executionManager__.verifyParams(
            messageDetails_.executionParams,
            msg.value
        );

        // verify message was part of the packet and
        // authenticated by respective switchboard
        _verify(
            executionDetails_.packetId,
            executionDetails_.proposalCount,
            remoteSlug,
            packedMessage,
            packetRoot,
            plugConfig,
            executionDetails_.decapacitorProof
        );

        // execute message
        _execute(
            executor,
            localPlug,
            remoteSlug,
            executionDetails_.executionGasLimit,
            messageDetails_
        );
    }

    ////////////////////////////////////////////////////////
    ////////////////// INTERNAL FUNCS //////////////////////
    ////////////////////////////////////////////////////////

    function _verify(
        bytes32 packetId_,
        uint256 proposalCount_,
        uint32 remoteChainSlug_,
        bytes32 packedMessage_,
        bytes32 packetRoot_,
        PlugConfig memory plugConfig_,
        bytes memory decapacitorProof_
    ) internal {
        // NOTE: is the the first un-trusted call in the system, another one is Plug.inbound
        if (
            !ISwitchboard(plugConfig_.inboundSwitchboard__).allowPacket(
                packetRoot_,
                packetId_,
                proposalCount_,
                remoteChainSlug_,
                rootProposedAt[packetId_][proposalCount_][
                    address(plugConfig_.inboundSwitchboard__)
                ]
            )
        ) revert VerificationFailed();

        if (
            !plugConfig_.decapacitor__.verifyMessageInclusion(
                packetRoot_,
                packedMessage_,
                decapacitorProof_
            )
        ) revert InvalidProof();
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the message
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     */
    function _execute(
        address executor_,
        address localPlug_,
        uint32 remoteChainSlug_,
        uint256 executionGasLimit_,
        ISocket.MessageDetails memory messageDetails_
    ) internal {
        // NOTE: external un-trusted call
        IPlug(localPlug_).inbound{gas: executionGasLimit_, value: msg.value}(
            remoteChainSlug_,
            messageDetails_.payload
        );

        executionManager__.updateExecutionFees(
            executor_,
            uint128(messageDetails_.executionFee),
            messageDetails_.msgId
        );
        emit ExecutionSuccess(messageDetails_.msgId);
    }

    /**
     * @dev Checks whether the specified packet has been proposed.
     * @param packetId_ The ID of the packet to check.
     * @param proposalCount_ The proposal ID of the packetId to check.
     * @param switchboard_ The address of switchboard for which this packet is proposed
     * @return A boolean indicating whether the packet has been proposed or not.
     */
    function isPacketProposed(
        bytes32 packetId_,
        uint256 proposalCount_,
        address switchboard_
    ) external view returns (bool) {
        return
            packetIdRoots[packetId_][proposalCount_][switchboard_] == bytes32(0)
                ? false
                : true;
    }

    /**
     * @dev Decodes the plug address from a given message id.
     * @param id_ The ID of the msg to decode the plug from.
     * @return plug_ The address of sibling plug decoded from the message ID.
     */
    function _decodePlug(bytes32 id_) internal pure returns (address plug_) {
        plug_ = address(uint160(uint256(id_) >> 64));
    }

    /**
     * @dev Decodes the chain ID from a given packet/message ID.
     * @param id_ The ID of the packet/msg to decode the chain slug from.
     * @return chainSlug_ The chain slug decoded from the packet/message ID.
     */
    function _decodeChainSlug(
        bytes32 id_
    ) internal view returns (uint32 chainSlug_) {
        chainSlug_ = uint32(uint256(id_) >> 224);
    }
}
