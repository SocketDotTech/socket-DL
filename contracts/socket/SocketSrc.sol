// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "./SocketBase.sol";

/**
 * @title SocketSrc
 * @dev The SocketSrc contract inherits from SocketBase and provides the functionality to send messages from the local chain to a remote chain via a Capacitor.
 */
abstract contract SocketSrc is SocketBase {
    error InsufficientFees();

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
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function outbound(
        uint32 remoteChainSlug_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable override returns (bytes32 msgId) {
        PlugConfig storage plugConfig = _plugConfigs[msg.sender][
            remoteChainSlug_
        ];
        uint32 localChainSlug = chainSlug;

        msgId = _encodeMsgId(localChainSlug);

        ISocket.Fees memory fees = _deductFees(
            msgGasLimit_,
            uint32(remoteChainSlug_),
            plugConfig.outboundSwitchboard__
        );

        bytes32 packedMessage = hasher__.packMessage(
            localChainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            fees.executionFee,
            payload_
        );

        plugConfig.capacitor__.addPackedMessage(packedMessage);
        emit MessageOutbound(
            localChainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            payload_,
            fees
        );
    }

    /**
     * @dev Deducts the fees needed for message transmission and execution
     * @param msgGasLimit_ The gas limit needed to execute the payload on the remote chain
     * @param remoteChainSlug_ The slug of the remote chain
     * @param switchboard__ The address of the switchboard contract
     * @return fees The fees object
     */
    function _deductFees(
        uint256 msgGasLimit_,
        uint32 remoteChainSlug_,
        ISwitchboard switchboard__
    ) internal returns (Fees memory fees) {
        uint256 minExecutionFees;
        (
            fees.transmissionFees,
            fees.switchboardFees,
            minExecutionFees
        ) = _getMinFees(msgGasLimit_, remoteChainSlug_, switchboard__);

        if (
            msg.value <
            fees.transmissionFees + fees.switchboardFees + minExecutionFees
        ) revert InsufficientFees();

        unchecked {
            // any extra fee is considered as executionFee
            fees.executionFee =
                msg.value -
                fees.transmissionFees -
                fees.switchboardFees;

            transmitManager__.payFees{value: fees.transmissionFees}(
                remoteChainSlug_
            );
            switchboard__.payFees{value: fees.switchboardFees}(
                remoteChainSlug_
            );
            executionManager__.payFees{value: fees.executionFee}(
                msgGasLimit_,
                remoteChainSlug_
            );
        }
    }

    /**
     * @notice Retrieves the minimum fees required for a message with a specified gas limit and destination chain.
     * @param msgGasLimit_ The gas limit of the message.
     * @param remoteChainSlug_ The slug of the destination chain for the message.
     * @param plug_ The address of the plug through which the message is sent.
     * @return totalFees The minimum fees required for the specified message.
     */
    function getMinFees(
        uint256 msgGasLimit_,
        uint32 remoteChainSlug_,
        address plug_
    ) external view override returns (uint256 totalFees) {
        PlugConfig storage plugConfig = _plugConfigs[plug_][remoteChainSlug_];

        (
            uint256 transmissionFees,
            uint256 switchboardFees,
            uint256 executionFee
        ) = _getMinFees(
                msgGasLimit_,
                remoteChainSlug_,
                plugConfig.outboundSwitchboard__
            );

        totalFees = transmissionFees + switchboardFees + executionFee;
    }

    function _getMinFees(
        uint256 msgGasLimit_,
        uint32 remoteChainSlug_,
        ISwitchboard switchboard__
    )
        internal
        view
        returns (
            uint256 transmissionFees,
            uint256 switchboardFees,
            uint256 executionFee
        )
    {
        transmissionFees = transmitManager__.getMinFees(remoteChainSlug_);

        uint256 verificationFee;
        (switchboardFees, verificationFee) = switchboard__.getMinFees(
            remoteChainSlug_
        );
        uint256 msgExecutionFee = executionManager__.getMinFees(
            msgGasLimit_,
            remoteChainSlug_
        );

        executionFee = msgExecutionFee + verificationFee;
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
        (bytes32 root, uint64 packetCount) = ICapacitor(capacitorAddress_)
            .sealPacket(batchSize_);

        bytes32 packetId = _encodePacketId(capacitorAddress_, packetCount);

        uint32 siblingChainSlug = capacitorToSlug[capacitorAddress_];
        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                siblingChainSlug,
                keccak256(abi.encode(siblingChainSlug, packetId, root)),
                signature_
            );

        if (!isTransmitter) revert InvalidAttester();
        emit PacketVerifiedAndSealed(transmitter, packetId, root, signature_);
    }

    // Packs the local plug, local chain slug, remote chain slug and nonce
    // messageCount++ will take care of msg id overflow as well
    // msgId(256) = localChainSlug(32) | nonce(224)
    function _encodeMsgId(uint32 slug_) internal returns (bytes32) {
        return bytes32((uint256(slug_) << 224) | messageCount++);
    }

    function _encodePacketId(
        address capacitorAddress_,
        uint256 packetCount_
    ) internal view returns (bytes32) {
        return
            bytes32(
                (uint256(chainSlug) << 224) |
                    (uint256(uint160(capacitorAddress_)) << 64) |
                    packetCount_
            );
    }
}
