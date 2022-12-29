// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "./SocketBase.sol";

abstract contract SocketSrc is SocketBase {
    // incrementing nonce, should be handled in next socket version.
    uint256 public _messageCount;

    /**
     * @notice emits the verification and seal confirmation of a packet
     * @param capacitorAddress address of capacitor at local
     * @param packetId packed id
     * @param signature signature of attester
     */
    event PacketVerifiedAndSealed(
        address indexed capacitorAddress,
        uint256 indexed packetId,
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
    ) external payable override {
        PlugConfig memory plugConfig = _plugConfigs[msg.sender][
            remoteChainSlug_
        ];

        // Packs the local plug, local chain slug, remote chain slug and nonce
        // _messageCount++ will take care of msg id overflow as well
        // msgId(256) = localChainSlug(32) | nonce(224)
        uint256 msgId = (uint256(uint32(_chainSlug)) << 224) | _messageCount++;

        // TODO: replace it with fees from switchboard
        // _vault__.deductFee{value: msg.value}(
        //     remoteChainSlug_,
        //     plugConfig.outboundIntegrationType
        // );

        bytes32 packedMessage = _hasher__.packMessage(
            _chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            payload_
        );

        plugConfig.capacitor__.addPackedMessage(packedMessage);
        emit MessageTransmitted(
            _chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.siblingPlug,
            msgId,
            msgGasLimit_,
            msg.value,
            payload_
        );
    }

    function seal(
        address capacitorAddress_,
        bytes calldata signature_
    ) external payable nonReentrant {
        // TODO: take sibling slug from configs (thought of mapping remote slugs and capacitors in registry)
        (bytes32 root, uint256 packetCount) = ICapacitor(capacitorAddress_)
            .sealPacket();

        uint256 packetId = _getPacketId(
            capacitorAddress_,
            _chainSlug,
            packetCount
        );

        if (
            !_transmitManager__.checkTransmitter(
                _chainSlug,
                0, // todo: get remoteChainSlug from config,
                root,
                signature_
            )
        ) revert InvalidAttester();

        emit PacketVerifiedAndSealed(capacitorAddress_, packetId, signature_);
    }

    function _getPacketId(
        address capacitorAddr_,
        uint256 chainSlug_,
        uint256 packetCount_
    ) internal pure returns (uint256 packetId) {
        packetId =
            (chainSlug_ << 224) |
            (uint256(uint160(capacitorAddr_)) << 64) |
            packetCount_;
    }
}
