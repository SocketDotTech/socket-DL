// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IAccumulator.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IHasher.sol";
import "../utils/ReentrancyGuard.sol";
import "./SocketConfig.sol";

interface ITransmitManager {
    function checkTransmitter(
        uint256 chainSlug,
        uint256 siblingChainSlug,
        bytes32 root,
        bytes calldata signature
    ) external view returns (bool);
}

abstract contract SocketLocal is SocketConfig, ReentrancyGuard {
    uint256 public chainSlug;
    // incrementing nonce, should be handled in next socket version.
    uint256 public _messageCount;

    IHasher public hasher;
    ITransmitManager public transmitManager;
    IVault public vault;

    error InvalidAttester();

    /**
     * @notice emits the verification and seal confirmation of a packet
     * @param accumAddress address of accumulator at local
     * @param packetId packed id
     * @param signature signature of attester
     */
    event PacketVerifiedAndSealed(
        address indexed accumAddress,
        uint256 indexed packetId,
        bytes signature
    );

    /**
     * @notice registers a message
     * @dev Packs the message and includes it in a packet with accumulator
     * @param remoteChainSlug_ the remote chain slug
     * @param msgGasLimit_ the gas limit needed to execute the payload on remote
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function outbound(
        uint256 remoteChainSlug_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable override {
        PlugConfig memory plugConfig = plugConfigs[msg.sender][
            remoteChainSlug_
        ];

        // Packs the local plug, local chain slug, remote chain slug and nonce
        // _messageCount++ will take care of msg id overflow as well
        // msgId(256) = localChainSlug(32) | nonce(224)
        uint256 msgId = (uint256(uint32(chainSlug)) << 224) | _messageCount++;

        // TODO: replace it with fees from switchboard
        vault.deductFee{value: msg.value}(
            remoteChainSlug_,
            plugConfig.outboundIntegrationType
        );

        bytes32 packedMessage = hasher.packMessage(
            chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.remotePlug,
            msgId,
            msgGasLimit_,
            payload_
        );

        IAccumulator(plugConfig.accum).addPackedMessage(packedMessage);
        emit MessageTransmitted(
            chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.remotePlug,
            msgId,
            msgGasLimit_,
            msg.value,
            payload_
        );
    }

    function seal(
        address accumAddress_,
        bytes calldata signature_
    ) external payable nonReentrant {
        // TODO: take sibling slug from configs (thought of mapping remote slugs and accums in registry)
        (
            bytes32 root,
            uint256 packetCount,
            uint256 remoteChainSlug
        ) = IAccumulator(accumAddress_).sealPacket();

        uint256 packetId = _getPacketId(accumAddress_, chainSlug, packetCount);

        if (
            !transmitManager.checkTransmitter(
                chainSlug,
                remoteChainSlug,
                root,
                signature_
            )
        ) revert InvalidAttester();

        emit PacketVerifiedAndSealed(accumAddress_, packetId, signature_);
    }

    function setHasher(address hasher_) external onlyOwner {
        hasher = IHasher(hasher_);
    }

    function setVault(address vault_) external onlyOwner {
        vault = IVault(vault_);
    }

    // TODO: in discussion
    /**
     * @notice updates transmitManager_
     * @param transmitManager_ address of Transmit Manager
     */
    function setTransmitManager(address transmitManager_) external onlyOwner {
        transmitManager = ITransmitManager(transmitManager_);
        emit TransmitManager(transmitManager_);
    }

    function _getPacketId(
        address accumAddr_,
        uint256 chainSlug_,
        uint256 packetCount_
    ) internal pure returns (uint256 packetId) {
        packetId =
            (chainSlug_ << 224) |
            (uint256(uint160(accumAddr_)) << 64) |
            packetCount_;
    }
}