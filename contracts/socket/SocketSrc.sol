// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "./SocketBase.sol";

/**
 * @title SocketSrc
 * @dev The SocketSrc contract inherits from SocketBase and provides the functionality
 * to send messages from the local chain to a remote chain via a capacitor, estimate min fees
 * and allow transmitters to seal packets for a path.
 */
abstract contract SocketSrc is SocketBase {
    // triggered when fees is not sufficient at outbound
    error InsufficientFees();
    // triggered when an invalid capacitor address is used for sealing
    error InvalidCapacitor();

    /**
     * @notice emits the verification and seal confirmation of a packet
     * @param transmitter address of transmitter recovered from sig
     * @param packetId packed packet id
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
     * @param siblingChainSlug_ the remote chain slug
     * @param minMsgGasLimit_ the gas limit needed to execute the payload on remote
     * @param executionParams_ a 32 bytes param to add extra details for execution
     * @param transmissionParams_ a 32 bytes param to add extra details for transmission
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function outbound(
        uint32 siblingChainSlug_,
        uint256 minMsgGasLimit_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        bytes calldata payload_
    ) external payable override returns (bytes32 msgId) {
        PlugConfig memory plugConfig;

        plugConfig.siblingPlug = _plugConfigs[msg.sender][siblingChainSlug_]
            .siblingPlug;
        plugConfig.capacitor__ = _plugConfigs[msg.sender][siblingChainSlug_]
            .capacitor__;
        plugConfig.outboundSwitchboard__ = _plugConfigs[msg.sender][
            siblingChainSlug_
        ].outboundSwitchboard__;

        msgId = _encodeMsgId(plugConfig.siblingPlug);

        // all the fees is transferred to execution manager and stored mapped to their addresses
        // transmit manager and switchboards can pull the fees from there
        // only external call is where we get min switchboard fees
        ISocket.Fees memory fees = _validateAndSendFees(
            minMsgGasLimit_,
            uint256(payload_.length),
            executionParams_,
            transmissionParams_,
            plugConfig.capacitor__.getMaxPacketLength(),
            uint32(siblingChainSlug_),
            plugConfig.outboundSwitchboard__
        );

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = msgId;
        messageDetails.minMsgGasLimit = minMsgGasLimit_;
        messageDetails.executionParams = executionParams_;
        messageDetails.payload = payload_;
        messageDetails.executionFee = fees.executionFee;

        // this packed message can be re-created if socket is redeployed with a new version
        // it is plug's responsibility to have proper checks in functions interacting
        // with socket to validate who has access to the contract at inbound
        bytes32 packedMessage = hasher__.packMessage(
            chainSlug,
            msg.sender,
            siblingChainSlug_,
            plugConfig.siblingPlug,
            messageDetails
        );

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
     * @param minMsgGasLimit_ The gas limit of the message.
     * @param payloadSize_ The byte length of payload of the message.
     * @param executionParams_ The extraParams required for execution.
     * @param transmissionParams_ The extraParams required for transmission.
     * @param siblingChainSlug_ The slug of the destination chain for the message.
     * @param switchboard_ The address of the switchboard through which the message is sent.
     * @param maxPacketLength_ The maxPacketLength for the capacitor used. Used for calculating transmission Fees.
     */
    function _validateAndSendFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        uint256 maxPacketLength_,
        uint32 siblingChainSlug_,
        ISwitchboard switchboard_
    ) internal returns (ISocket.Fees memory fees) {
        uint128 verificationFees;
        (fees.switchboardFees, verificationFees) = _getSwitchboardMinFees(
            siblingChainSlug_,
            switchboard_
        );

        (fees.executionFee, fees.transmissionFees) = executionManager__
            .payAndCheckFees{value: msg.value}(
            minMsgGasLimit_,
            payloadSize_,
            executionParams_,
            transmissionParams_,
            siblingChainSlug_,
            fees.switchboardFees / uint128(maxPacketLength_),
            verificationFees / uint128(maxPacketLength_),
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
     * @return switchboardFees , verificationFees The minimum fees for message execution
     */
    function _getSwitchboardMinFees(
        uint32 siblingChainSlug_,
        ISwitchboard switchboard__
    )
        internal
        view
        returns (uint128 switchboardFees, uint128 verificationFees)
    {
        (switchboardFees, verificationFees) = switchboard__.getMinFees(
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
        uint128 verificationFees;
        uint128 msgExecutionFee;
        (switchboardFees, verificationFees) = _getSwitchboardMinFees(
            siblingChainSlug_,
            switchboard__
        );
        switchboardFees = switchboardFees / uint128(maxPacketLength_);
        (msgExecutionFee, transmissionFees) = executionManager__
            .getExecutionTransmissionMinFees(
                minMsgGasLimit_,
                payloadSize_,
                executionParams_,
                siblingChainSlug_,
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
