// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./SocketBase.sol";

/**
 * @title SocketSrc
 * @dev The SocketSrc contract inherits from SocketBase and provides the functionality
 * to send messages from the local chain to a remote chain via a capacitor, estimate min fees
 * and allow transmitters to seal packets for a path.
 */
abstract contract SocketSrc is SocketBase {
    error InsufficientFees();
    error InvalidCapacitor();

    /**
     * @notice emits the verification and seal confirmation of a packet
     * @param transmitter address of transmitter recovered from sig
     * @param packetId packed id
     * @param root root
     * @param signature signature of attester
     */
    event PacketVerifiedAndSealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        bytes32 root,
        bytes signature
    );

    /**
     * @notice registers a message
     * @dev Packs the message and includes it in a packet with capacitor
     * @param remoteChainSlug_ the remote chain slug
     * @param msgGasLimit_ the gas limit needed to execute the payload on remote
     * @param executionParams_ a 32 bytes param to add extra details for execution
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function outbound(
        uint32 remoteChainSlug_,
        uint256 msgGasLimit_,
        bytes32 executionParams_,
        bytes calldata payload_
    ) external payable override returns (bytes32 msgId) {
        PlugConfig memory plugConfig;

        plugConfig.siblingPlug = _plugConfigs[msg.sender][remoteChainSlug_]
            .siblingPlug;
        plugConfig.capacitor__ = _plugConfigs[msg.sender][remoteChainSlug_]
            .capacitor__;
        plugConfig.outboundSwitchboard__ = _plugConfigs[msg.sender][
            remoteChainSlug_
        ].outboundSwitchboard__;

        msgId = _encodeMsgId(plugConfig.siblingPlug);

        ISocket.Fees memory fees = _validateAndSendFees(
            msgGasLimit_,
            uint256(payload_.length),
            executionParams_,
            uint32(remoteChainSlug_),
            plugConfig.outboundSwitchboard__,
            plugConfig.capacitor__.getMaxPacketLength()
        );

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = msgId;
        messageDetails.msgGasLimit = msgGasLimit_;
        messageDetails.executionParams = executionParams_;
        messageDetails.payload = payload_;
        messageDetails.executionFee = fees.executionFee;

        bytes32 packedMessage = hasher__.packMessage(
            chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            messageDetails
        );

        plugConfig.capacitor__.addPackedMessage(packedMessage);

        emit MessageOutbound(
            chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            executionParams_,
            payload_,
            fees
        );
    }

    /**
     * @notice Validates if enough fee is provided for message execution. If yes, fees is sent and stored in execution manager.
     * @param msgGasLimit_ The gas limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param remoteChainSlug_ The slug of the destination chain for the message.
     * @param switchboard__ The address of the switchboard through which the message is sent.
     * @param maxPacketLength_ The maxPacketLength for the capacitor used. Used for calculating transmission Fees.
     */
    function _validateAndSendFees(
        uint256 msgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 remoteChainSlug_,
        ISwitchboard switchboard__,
        uint256 maxPacketLength_
    ) internal returns (ISocket.Fees memory fees) {
        uint128 verificationFees;
        (fees.switchboardFees, verificationFees) = _getSwitchboardMinFees(
            remoteChainSlug_,
            switchboard__
        );

        (fees.executionFee, fees.transmissionFees) = executionManager__
            .payAndCheckFees{value: msg.value}(
            msgGasLimit_,
            payloadSize_,
            executionParams_,
            remoteChainSlug_,
            fees.switchboardFees / uint128(maxPacketLength_),
            verificationFees / uint128(maxPacketLength_),
            address(transmitManager__),
            address(switchboard__),
            maxPacketLength_
        );
    }

    /**
     * @notice Retrieves the minimum fees required for a message with a specified gas limit and destination chain.
     * @param msgGasLimit_ The gas limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param remoteChainSlug_ The slug of the destination chain for the message.
     * @param plug_ The address of the plug through which the message is sent.
     * @return totalFees The minimum fees required for the specified message.
     */
    function getMinFees(
        uint256 msgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 remoteChainSlug_,
        address plug_
    ) external view override returns (uint256 totalFees) {
        ICapacitor capacitor__ = _plugConfigs[plug_][remoteChainSlug_]
            .capacitor__;
        uint256 maxPacketLength = capacitor__.getMaxPacketLength();
        (
            uint128 transmissionFees,
            uint128 switchboardFees,
            uint128 executionFees
        ) = _getAllMinFees(
                msgGasLimit_,
                payloadSize_,
                executionParams_,
                remoteChainSlug_,
                _plugConfigs[plug_][remoteChainSlug_].outboundSwitchboard__,
                maxPacketLength
            );
        totalFees = transmissionFees + switchboardFees + executionFees;
    }

    /**
     * @notice Retrieves the minimum fees required for switchboard.
     * @param remoteChainSlug_ The slug of the destination chain for the message.
     * @param switchboard__ The switchboard address for which fees is retrieved.
     * @return switchboardFees , verificationFees The minimum fees for message execution
     */
    function _getSwitchboardMinFees(
        uint32 remoteChainSlug_,
        ISwitchboard switchboard__
    )
        internal
        view
        returns (uint128 switchboardFees, uint128 verificationFees)
    {
        (switchboardFees, verificationFees) = switchboard__.getMinFees(
            remoteChainSlug_
        );
    }

    /**
     * @notice Retrieves the minimum fees required for a message with a specified gas limit and destination chain.
     * @param msgGasLimit_ The gas limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param remoteChainSlug_ The slug of the destination chain for the message.
     * @param switchboard__ The address of the switchboard through which the message is sent.
     */
    function _getAllMinFees(
        uint256 msgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        uint32 remoteChainSlug_,
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
        uint128 verificationFees;
        uint128 msgExecutionFee;
        (switchboardFees, verificationFees) = _getSwitchboardMinFees(
            remoteChainSlug_,
            switchboard__
        );
        switchboardFees = switchboardFees / uint128(maxPacketLength_);
        (msgExecutionFee, transmissionFees) = executionManager__
            .getExecutionTransmissionMinFees(
                msgGasLimit_,
                payloadSize_,
                executionParams_,
                remoteChainSlug_,
                address(transmitManager__)
            );

        executionFees =
            msgExecutionFee +
            verificationFees /
            uint128(maxPacketLength_);
    }

    /**
     * @notice seals data in capacitor for specific batchSizr
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
        if (siblingChainSlug == 0) revert InvalidCapacitor();

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
        emit PacketVerifiedAndSealed(transmitter, packetId, root, signature_);
    }

    // Packs the local plug, local chain slug, remote chain slug and nonce
    // messageCount++ will take care of msg id overflow as well
    // msgId(256) = localChainSlug(32) | siblingPlug_(160) | nonce(64)
    function _encodeMsgId(address siblingPlug_) internal returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(siblingPlug_)) << 64) |
                    messageCount++
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
