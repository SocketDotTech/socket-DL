// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "./SocketBase.sol";

abstract contract SocketSrc is SocketBase {
    // incrementing nonce, should be handled in next socket version.
    uint256 public messageCount;

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
        uint256 indexed packetId,
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
        uint256 remoteChainSlug_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable override returns (uint256 msgId) {
        PlugConfig storage plugConfig = _plugConfigs[
            (uint256(uint160(msg.sender)) << 96) | remoteChainSlug_
        ];
        uint256 localChainSlug = chainSlug;

        // Packs the local plug, local chain slug, remote chain slug and nonce
        // messageCount++ will take care of msg id overflow as well
        // msgId(256) = localChainSlug(32) | nonce(224)
        msgId = (uint256(uint32(localChainSlug)) << 224) | messageCount++;

        uint256 executionFee = _deductFees(
            msgGasLimit_,
            remoteChainSlug_,
            plugConfig.outboundSwitchboard__
        );

        bytes32 packedMessage = hasher__.packMessage(
            localChainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            executionFee,
            payload_
        );

        plugConfig.capacitor__.addPackedMessage(packedMessage);
        emit MessageTransmitted(
            localChainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            executionFee,
            msg.value,
            payload_
        );
    }

    function _deductFees(
        uint256 msgGasLimit_,
        uint256 remoteChainSlug_,
        ISwitchboard switchboard__
    ) internal returns (uint256 executionFee) {
        (
            uint256 transmitFees,
            uint256 switchboardFees,
            uint256 verificationFee,
            uint256 msgExecutionFee
        ) = _getFees(msgGasLimit_, remoteChainSlug_, switchboard__);

        if (
            msg.value <
            transmitFees + switchboardFees + verificationFee + msgExecutionFee
        ) revert InsufficientFees();

        unchecked {
            // any extra fee is considered as executionFee
            executionFee = msg.value - transmitFees - switchboardFees;

            transmitManager__.payFees{value: transmitFees}(remoteChainSlug_);
            switchboard__.payFees{value: switchboardFees}(remoteChainSlug_);
            executionManager__.payFees{value: executionFee}(
                msgGasLimit_,
                remoteChainSlug_
            );
        }
    }

    function getMinFees(
        uint256 msgGasLimit_,
        uint256 remoteChainSlug_,
        address plug_
    ) external view returns (uint256 executionFee) {
        PlugConfig storage plugConfig = _plugConfigs[
            (uint256(uint160(plug_)) << 96) | remoteChainSlug_
        ];

        (
            uint256 transmitFees,
            uint256 switchboardFees,
            uint256 verificationFee,
            uint256 msgExecutionFee
        ) = _getFees(
                msgGasLimit_,
                remoteChainSlug_,
                plugConfig.outboundSwitchboard__
            );

        executionFee =
            transmitFees +
            switchboardFees +
            verificationFee +
            msgExecutionFee;
    }

    function _getFees(
        uint256 msgGasLimit_,
        uint256 remoteChainSlug_,
        ISwitchboard switchboard__
    )
        internal
        view
        returns (
            uint256 transmitFees,
            uint256 switchboardFees,
            uint256 verificationFee,
            uint256 msgExecutionFee
        )
    {
        transmitFees = transmitManager__.getMinFees(remoteChainSlug_);
        (switchboardFees, verificationFee) = switchboard__.getMinFees(
            remoteChainSlug_
        );
        msgExecutionFee = executionManager__.getMinFees(
            msgGasLimit_,
            remoteChainSlug_
        );
    }

    function seal(
        address capacitorAddress_,
        bytes calldata signature_
    ) external payable nonReentrant {
        (bytes32 root, uint256 packetCount) = ICapacitor(capacitorAddress_)
            .sealPacket();

        uint256 packetId = (chainSlug << 224) |
            (uint256(uint160(capacitorAddress_)) << 64) |
            packetCount;

        uint256 siblingChainSlug = capacitorToSlug[capacitorAddress_];

        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                siblingChainSlug,
                keccak256(abi.encode(siblingChainSlug, packetId, root)),
                signature_
            );

        if (!isTransmitter) revert InvalidAttester();
        emit PacketVerifiedAndSealed(transmitter, packetId, root, signature_);
    }
}
