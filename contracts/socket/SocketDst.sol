// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

// import "../interfaces/IVerifier.sol";
import "../interfaces/IDecapacitor.sol";
import "../interfaces/IPlug.sol";
import "./SocketBase.sol";

abstract contract SocketDst is SocketBase {
    enum PacketStatus {
        NOT_PROPOSED,
        PROPOSED
    }

    enum MessageStatus {
        NOT_EXECUTED,
        SUCCESS,
        FAILED
    }

    error InvalidProof();
    error InvalidRetry();
    error VerificationFailed();
    error MessageAlreadyExecuted();
    error AlreadyAttested();

    // keccak256("EXECUTOR")
    bytes32 private constant EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;

    // msgId => executorAddress
    mapping(uint256 => address) public executor;
    // msgId => message status
    mapping(uint256 => MessageStatus) public messageStatus;
    // capacitorAddr|chainSlug|packetId
    mapping(uint256 => bytes32) public override remoteRoots;
    mapping(uint256 => uint256) public rootProposedAt;

    /**
     * @notice emits the packet details when proposed at remote
     * @param attester address of attester
     * @param packetId packet id
     * @param root packet root
     */
    event PacketAttested(
        address indexed attester,
        uint256 indexed packetId,
        bytes32 root
    );

    /**
     * @notice emits the root details when root is replaced by owner
     * @param packetId packet id
     * @param oldRoot old root
     * @param newRoot old root
     */
    event PacketRootUpdated(uint256 packetId, bytes32 oldRoot, bytes32 newRoot);

    function propose(
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external {
        if (remoteRoots[packetId_] != bytes32(0)) revert AlreadyAttested();
        (address transmitter, bool isTransmitter) = _transmitManager__
            .checkTransmitter(
                (_getChainSlug(packetId_) << 128) | _chainSlug,
                packetId_,
                root_,
                signature_
            );
        if (!isTransmitter) revert InvalidAttester();

        remoteRoots[packetId_] = root_;
        rootProposedAt[packetId_] = block.timestamp;

        emit PacketAttested(transmitter, packetId_, root_);
    }

    /**
     * @notice executes a message
     * @param msgGasLimit gas limit needed to execute the inbound at remote
     * @param msgId message id packed with local plug, local chainSlug, remote ChainSlug and nonce
     * @param localPlug remote plug address
     * @param payload the data which is needed by plug at inbound call on remote
     * @param verifyParams_ the details needed for message verification
     */
    function execute(
        uint256 msgGasLimit,
        uint256 msgId,
        address localPlug,
        bytes calldata payload,
        ISocket.VerificationParams calldata verifyParams_
    ) external override nonReentrant onlyRole(EXECUTOR_ROLE) {
        if (executor[msgId] != address(0)) revert MessageAlreadyExecuted();

        // todo: to decide if this should be just a bool (was added for fees here)
        executor[msgId] = msg.sender;

        PlugConfig memory plugConfig = _plugConfigs[
            (uint256(uint160(localPlug)) << 96) | verifyParams_.remoteChainSlug
        ];

        bytes32 packedMessage = _hasher__.packMessage(
            verifyParams_.remoteChainSlug,
            plugConfig.siblingPlug,
            _chainSlug,
            localPlug,
            msgId,
            msgGasLimit,
            payload
        );

        _verify(packedMessage, plugConfig, verifyParams_);
        _execute(
            localPlug,
            verifyParams_.remoteChainSlug,
            msgGasLimit,
            msgId,
            payload
        );
    }

    function _verify(
        bytes32 packedMessage,
        PlugConfig memory plugConfig,
        ISocket.VerificationParams calldata verifyParams_
    ) internal view {
        if (
            !ISwitchboard(plugConfig.inboundSwitchboard__).allowPacket(
                remoteRoots[verifyParams_.packetId],
                verifyParams_.packetId,
                verifyParams_.remoteChainSlug,
                rootProposedAt[verifyParams_.packetId]
            )
        ) revert VerificationFailed();

        if (
            !plugConfig.decapacitor__.verifyMessageInclusion(
                remoteRoots[verifyParams_.packetId],
                packedMessage,
                verifyParams_.decapacitorProof
            )
        ) revert InvalidProof();
    }

    function _execute(
        address localPlug,
        uint256 remoteChainSlug,
        uint256 msgGasLimit,
        uint256 msgId,
        bytes calldata payload
    ) internal {
        try
            IPlug(localPlug).inbound{gas: msgGasLimit}(remoteChainSlug, payload)
        {
            messageStatus[msgId] = MessageStatus.SUCCESS;
            emit ExecutionSuccess(msgId);
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            messageStatus[msgId] = MessageStatus.FAILED;
            emit ExecutionFailed(msgId, reason);
        } catch (bytes memory reason) {
            // catch failing assert()
            messageStatus[msgId] = MessageStatus.FAILED;
            emit ExecutionFailedBytes(msgId, reason);
        }
    }

    /**
     * @notice updates root for given packet id
     * @param packetId_ id of packet to be updated
     * @param newRoot_ new root
     */
    function updatePacketRoot(
        uint256 packetId_,
        bytes32 newRoot_
    ) external onlyOwner {
        bytes32 oldRoot = remoteRoots[packetId_];
        remoteRoots[packetId_] = newRoot_;

        emit PacketRootUpdated(packetId_, oldRoot, newRoot_);
    }

    /**
     * @notice adds an executor
     * @param executor_ executor address
     */
    function grantExecutorRole(address executor_) external onlyOwner {
        _grantRole(EXECUTOR_ROLE, executor_);
    }

    /**
     * @notice removes an executor from `remoteChainSlug_` chain list
     * @param executor_ executor address
     */
    function revokeExecutorRole(address executor_) external onlyOwner {
        _revokeRole(EXECUTOR_ROLE, executor_);
    }

    function getPacketStatus(
        uint256 packetId_
    ) external view returns (PacketStatus status) {
        return
            remoteRoots[packetId_] == bytes32(0)
                ? PacketStatus.NOT_PROPOSED
                : PacketStatus.PROPOSED;
    }

    function _getChainSlug(
        uint256 packetId_
    ) internal pure returns (uint256 chainSlug_) {
        chainSlug_ = uint32(packetId_ >> 224);
    }
}
