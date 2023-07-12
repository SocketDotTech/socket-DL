// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./SocketBase.sol";

/**
 * @title SocketSrc
 * @dev The SocketSrc contract inherits from SocketBase and handles all the operations that
 * happen on the source side. Provides the following functions
 * 1. Sending messages from the local chain to a remote chain
 * 2. Estimating minFees for message transmission, verification and execution
 * 3. Sealing packets and making them ready to be transmitted
 */
abstract contract SocketSrc is SocketBase {
    ////////////////////////////////////////////////////////
    ////////////////////// ERRORS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @dev Error triggerred when invalid capacitor address is provided
     */
    error InvalidCapacitorAddress();

    /**
     * @dev Error triggerred when siblingPlug is not found
     */
    error PlugDisconnected();

    ////////////////////////////////////////////////////////
    ////////////////////// EVENTS //////////////////////////
    ////////////////////////////////////////////////////////

    /**
     * @notice Emits as soon as a capacitor is sealed
     * @param transmitter address of transmitter that sealed this packet(recovered from sig)
     * @param packetId packed-packet id
     * @param root root of the packet
     * @param signature signature of transmitter
     */
    event Sealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        uint256 batchSize,
        bytes32 root,
        bytes signature
    );

    /**
     * @notice emits the message details when a new message arrives at outbound
     * @param localChainSlug local chain slug
     * @param localPlug local plug address
     * @param dstChainSlug remote chain slug
     * @param dstPlug remote plug address
     * @param msgId message id packed with remoteChainSlug and nonce
     * @param minMsgGasLimit gas limit needed to execute the inbound at remote
     * @param payload the data which will be used by inbound at remote
     */
    event MessageOutbound(
        uint32 localChainSlug,
        address localPlug,
        uint32 dstChainSlug,
        address dstPlug,
        bytes32 msgId,
        uint256 minMsgGasLimit,
        bytes32 executionParams,
        bytes32 transmissionParams,
        bytes payload,
        Fees fees
    );

    /**
     * @notice To send message to a connected remote chain. Should only be called by a plug.
     * @param siblingChainSlug_ the remote chain slug
     * @param minMsgGasLimit_ the minimum gas-limit needed to execute the payload on remote
     * @param executionParams_ a 32 bytes param to add details for execution, for eg: fees to be paid for execution
     * @param transmissionParams_ a 32 bytes param to add extra details for transmission
     * @param payload_ bytes to be delivered to the Plug on the siblingChainSlug_
     */
    function outbound(
        uint32 siblingChainSlug_,
        uint256 minMsgGasLimit_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        bytes calldata payload_
    ) external payable override returns (bytes32 msgId) {
        PlugConfig memory plugConfig;

        // looks up the sibling plug address using the msg.sender as the local plug address
        plugConfig.siblingPlug = _plugConfigs[msg.sender][siblingChainSlug_]
            .siblingPlug;

        // if no sibling plug is found for the given chain slug, revert
        if (plugConfig.siblingPlug == address(0)) revert PlugDisconnected();

        // fetches auxillary details for the message from the plug config
        plugConfig.capacitor__ = _plugConfigs[msg.sender][siblingChainSlug_]
            .capacitor__;
        plugConfig.outboundSwitchboard__ = _plugConfigs[msg.sender][
            siblingChainSlug_
        ].outboundSwitchboard__;

        // creates a unique ID for the message
        msgId = _encodeMsgId(plugConfig.siblingPlug);

        // validate if caller has send enough fees, if yes, send fees to execution manager
        // for parties to claim later
        ISocket.Fees memory fees = _validateAndSendFees(
            minMsgGasLimit_,
            uint256(payload_.length),
            executionParams_,
            transmissionParams_,
            plugConfig.outboundSwitchboard__,
            plugConfig.capacitor__.getMaxPacketLength(),
            siblingChainSlug_
        );

        ISocket.MessageDetails memory messageDetails = ISocket.MessageDetails({
            msgId: msgId,
            minMsgGasLimit: minMsgGasLimit_,
            executionParams: executionParams_,
            payload: payload_,
            executionFee: fees.executionFee
        });

        // create a compressed data-struct called PackedMessage
        // which has the message payload and some configuration details
        bytes32 packedMessage = hasher__.packMessage(
            chainSlug,
            msg.sender,
            siblingChainSlug_,
            plugConfig.siblingPlug,
            messageDetails
        );

        // finally add packedMessage to the capacitor to generate new root
        plugConfig.capacitor__.addPackedMessage(packedMessage);

        emit MessageOutbound(
            chainSlug,
            msg.sender,
            siblingChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            minMsgGasLimit_,
            executionParams_,
            transmissionParams_,
            payload_,
            fees
        );
    }

    /**
     * @notice Validates if enough fee is provided for message execution. If yes, fees is sent and stored in execution manager.
     * @param minMsgGasLimit_ the min gas-limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param transmissionParams_ The extraParams required for transmission.
     * @param switchboard_ The address of the switchboard through which the message is sent.
     * @param maxPacketLength_ The maxPacketLength for the capacitor used. Used for calculating transmission Fees.
     * @param siblingChainSlug_ The slug of the destination chain for the message.
     */
    function _validateAndSendFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        ISwitchboard switchboard_,
        uint256 maxPacketLength_,
        uint32 siblingChainSlug_
    ) internal returns (ISocket.Fees memory fees) {
        uint128 verificationFeePerMessage;
        // switchboard is plug configured and this is an external untrusted call
        (
            fees.switchboardFees,
            verificationFeePerMessage
        ) = _getSwitchboardMinFees(siblingChainSlug_, switchboard_);

        // deposits msg.value to execution manager and checks if enough fees is provided
        (fees.executionFee, fees.transmissionFees) = executionManager__
            .payAndCheckFees{value: msg.value}(
            minMsgGasLimit_,
            payloadSize_,
            executionParams_,
            transmissionParams_,
            siblingChainSlug_,
            fees.switchboardFees / uint128(maxPacketLength_),
            verificationFeePerMessage,
            address(transmitManager__),
            address(switchboard_),
            maxPacketLength_
        );
    }

    /**
     * @notice Retrieves the minimum fees required for a message with a specified gas limit and destination chain.
     * @param minMsgGasLimit_ The gas limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param siblingChainSlug_ The slug of the destination chain for the message.
     * @param plug_ The address of the plug through which the message is sent.
     * @return totalFees The minimum fees required for the specified message.
     */
    function getMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        uint32 siblingChainSlug_,
        address plug_
    ) external view override returns (uint256 totalFees) {
        ICapacitor capacitor__ = _plugConfigs[plug_][siblingChainSlug_]
            .capacitor__;
        uint256 maxPacketLength = capacitor__.getMaxPacketLength();
        (
            uint128 transmissionFees,
            uint128 switchboardFees,
            uint128 executionFees
        ) = _getAllMinFees(
                minMsgGasLimit_,
                payloadSize_,
                executionParams_,
                transmissionParams_,
                siblingChainSlug_,
                _plugConfigs[plug_][siblingChainSlug_].outboundSwitchboard__,
                maxPacketLength
            );
        totalFees = transmissionFees + switchboardFees + executionFees;
    }

    /**
     * @notice Retrieves the minimum fees required for switchboard.
     * @param siblingChainSlug_ The slug of the destination chain for the message.
     * @param switchboard__ The switchboard address for which fees is retrieved.
     * @return switchboardFees fees required for message verification
     */
    function _getSwitchboardMinFees(
        uint32 siblingChainSlug_,
        ISwitchboard switchboard__
    )
        internal
        view
        returns (uint128 switchboardFees, uint128 verificationOverheadFees)
    {
        (switchboardFees, verificationOverheadFees) = switchboard__.getMinFees(
            siblingChainSlug_
        );
    }

    /**
     * @notice Retrieves the minimum fees required for a message with a specified gas limit and destination chain.
     * @param minMsgGasLimit_ The gas limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param siblingChainSlug_ The slug of the destination chain for the message.
     * @param switchboard__ The address of the switchboard through which the message is sent.
     */
    function _getAllMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        uint32 siblingChainSlug_,
        ISwitchboard switchboard__,
        uint256 maxPacketLength_
    )
        internal
        view
        returns (
            uint128 transmissionFees,
            uint128 switchboardFees,
            uint128 executionFees
        )
    {
        uint128 verificationOverheadFees;
        uint128 msgExecutionFee;
        (switchboardFees, verificationOverheadFees) = _getSwitchboardMinFees(
            siblingChainSlug_,
            switchboard__
        );
        switchboardFees /= uint128(maxPacketLength_);
        (msgExecutionFee, transmissionFees) = executionManager__
            .getExecutionTransmissionMinFees(
                minMsgGasLimit_,
                payloadSize_,
                executionParams_,
                transmissionParams_,
                siblingChainSlug_,
                address(transmitManager__)
            );

        transmissionFees /= uint128(maxPacketLength_);
        executionFees = msgExecutionFee + verificationOverheadFees;
    }

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
    ) external payable override {
        uint32 siblingChainSlug = capacitorToSlug[capacitorAddress_];
        if (siblingChainSlug == 0) revert InvalidCapacitorAddress();

        (bytes32 root, uint64 packetCount) = ICapacitor(capacitorAddress_)
            .sealPacket(batchSize_);

        bytes32 packetId = _encodePacketId(capacitorAddress_, packetCount);
        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                siblingChainSlug,
                keccak256(
                    abi.encode(version, siblingChainSlug, packetId, root)
                ),
                signature_
            );

        if (!isTransmitter) revert InvalidTransmitter();
        emit Sealed(transmitter, packetId, batchSize_, root, signature_);
    }

    // Packs the local plug, local chain slug, remote chain slug and nonce
    // globalMessageCount++ will take care of msg id overflow as well
    // msgId(256) = localChainSlug(32) | siblingPlug_(160) | nonce(64)
    function _encodeMsgId(address siblingPlug_) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(siblingPlug_)) << 64) |
                    globalMessageCount++
            );
    }

    function _encodePacketId(
        address capacitorAddress_,
        uint64 packetCount_
    ) internal view returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(capacitorAddress_)) << 64) |
                    packetCount_
            );
    }
}
