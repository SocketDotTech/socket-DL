// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IDeaccumulator.sol";
import "../interfaces/IVerifier.sol";
import "../interfaces/IPlug.sol";

import "./SocketLocal.sol";

contract Socket is SocketLocal {
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
    error ExecutorNotFound();
    error AlreadyAttested();

    address public proposer;
    // keccak256("EXECUTOR")
    bytes32 private constant EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;

    // msgId => executorAddress
    mapping(uint256 => address) public executor;
    // msgId => message status
    mapping(uint256 => MessageStatus) public messageStatus;
    // accumAddr|chainSlug|packetId
    mapping(bytes32 => bool) public remoteRoots;

    /**
     * @notice emits the packet details when proposed at remote
     * @param attester address of attester
     * @param root packet root
     */
    event PacketAttested(address indexed attester, bytes32 root);

    /**
     * @notice emits the root when it is removed by owner
     * @param oldRoot old root
     */
    event PacketRootRemoved(bytes32 oldRoot);

    /**
     * @param chainSlug_ socket chain slug (should not be more than uint32)
     */
    constructor(
        uint32 chainSlug_,
        address hasher_,
        address signatureVerifier_,
        address vault_
    ) SocketLocal(chainSlug_, hasher_, signatureVerifier_, vault_) {}

    function attest(bytes32 root_) external {
        if (msg.sender != proposer) revert InvalidAttester();
        if (remoteRoots[root_]) revert AlreadyAttested();
        remoteRoots[root_] = true;

        emit PacketAttested(msg.sender, root_);
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
    ) external override nonReentrant {
        if (!_hasRole(EXECUTOR_ROLE, msg.sender)) revert ExecutorNotFound();
        if (executor[msgId] != address(0)) revert MessageAlreadyExecuted();
        executor[msgId] = msg.sender;

        PlugConfig memory plugConfig = plugConfigs[localPlug][
            verifyParams_.remoteChainSlug
        ];

        bytes32 packedMessage = hasher.packMessage(
            verifyParams_.remoteChainSlug,
            plugConfig.remotePlug,
            chainSlug,
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

    function retryExecute(
        uint256 newMsgGasLimit,
        uint256 msgId,
        uint256 msgGasLimit,
        address localPlug,
        bytes calldata payload,
        ISocket.VerificationParams calldata verifyParams_
    ) external override nonReentrant {
        if (!_hasRole(EXECUTOR_ROLE, msg.sender)) revert ExecutorNotFound();
        if (messageStatus[msgId] != MessageStatus.FAILED) revert InvalidRetry();
        executor[msgId] = msg.sender;

        PlugConfig memory plugConfig = plugConfigs[localPlug][
            verifyParams_.remoteChainSlug
        ];

        bytes32 packedMessage = hasher.packMessage(
            verifyParams_.remoteChainSlug,
            plugConfig.remotePlug,
            chainSlug,
            localPlug,
            msgId,
            msgGasLimit,
            payload
        );

        _verify(packedMessage, plugConfig, verifyParams_);
        _execute(
            localPlug,
            verifyParams_.remoteChainSlug,
            newMsgGasLimit,
            msgId,
            payload
        );
    }

    function _verify(
        bytes32 packedMessage,
        PlugConfig memory plugConfig,
        ISocket.VerificationParams calldata verifyParams_
    ) internal view {
        (bool isVerified, bytes32 root) = IVerifier(plugConfig.verifier)
            .verifyPacket(
                verifyParams_.packetId,
                plugConfig.inboundIntegrationType
            );

        if (!isVerified) revert VerificationFailed();

        if (
            !IDeaccumulator(plugConfig.deaccum).verifyMessageInclusion(
                root,
                packedMessage,
                verifyParams_.deaccumProof
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
     * @notice discards root
     * @param oldRoot_ existing root
     */
    function removePacketRoot(bytes32 oldRoot_) external onlyOwner {
        remoteRoots[oldRoot_] = false;
        emit PacketRootRemoved(oldRoot_);
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
        bytes32 root_
    ) external view returns (PacketStatus status) {
        return
            !remoteRoots[root_]
                ? PacketStatus.NOT_PROPOSED
                : PacketStatus.PROPOSED;
    }
}
