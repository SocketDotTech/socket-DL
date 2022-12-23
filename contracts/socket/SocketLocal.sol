// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IVault.sol";
import "../interfaces/IHasher.sol";
import "../interfaces/ISignatureVerifier.sol";
import "../utils/ReentrancyGuard.sol";
import "./SocketConfig.sol";

// TODO: replace it with IAccumulator in interfaces/
interface IAccumulator {
    /**
     * @notice adds the packed message to a packet
     * @dev this should be only executable by socket
     * @dev it will be later replaced with a function adding each message to a merkle tree
     * @param packedMessage the message packed with payload, fees and config
     */
    function addPackedMessage(bytes32 packedMessage) external;

    /**
     * @notice seals the packet
     * @dev also indicates the packet is ready to be shipped and no more messages can be added now.
     * @dev this should be executable by notary only
     * @return root root hash of the packet
     * @return remoteChainSlug remote chain slug for the packet sealed
     */
    function sealPacket()
        external
        returns (bytes32 root, uint256 remoteChainSlug);
}

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
    ISignatureVerifier public signatureVerifier;
    ITransmitManager public transmitManager;
    IVault public vault;

    error InvalidAttester();

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

    function seal(address accumAddress_, bytes calldata signature_) external {
        // TODO: take sibling slug from configs (thought of mapping remote slugs and accums in registry)
        (bytes32 root, uint256 remoteChainSlug) = IAccumulator(accumAddress_)
            .sealPacket();

        if (
            !transmitManager.checkTransmitter(
                chainSlug,
                remoteChainSlug,
                root,
                signature_
            )
        ) revert InvalidAttester();

        emit PacketVerifiedAndSealed(msg.sender, accumAddress_, signature_);
    }

    function setHasher(address hasher_) external onlyOwner {
        hasher = IHasher(hasher_);
    }

    function setVault(address vault_) external onlyOwner {
        vault = IVault(vault_);
    }

    /**
     * @notice updates signatureVerifier_
     * @param signatureVerifier_ address of Signature Verifier
     */
    function setSignatureVerifier(
        address signatureVerifier_
    ) external onlyOwner {
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
        emit SignatureVerifierSet(signatureVerifier_);
    }

    /**
     * @notice updates transmitManager_
     * @param transmitManager_ address of Transmit Manager
     */
    function setTransmitManager(address transmitManager_) external onlyOwner {
        transmitManager = ITransmitManager(transmitManager_);
        emit TransmitManager(transmitManager_);
    }
}
