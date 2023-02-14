// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IDecapacitor.sol";
import "../interfaces/IPlug.sol";

import "./SocketBase.sol";

abstract contract SocketDst is SocketBase {
    error AlreadyAttested();
    error InvalidProof();
    error InvalidRetry();
    error MessageAlreadyExecuted();
    error NotExecutor();
    error VerificationFailed();

    // srcChainSlug => switchboardAddress => executorAddress => fees
    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public feesEarned;
    // msgId => message status
    mapping(uint256 => bool) public messageExecuted;
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
     * @param packetId packet id
     * @param localPlug remote plug address
     * @param messageDetails_ the details needed for message verification
     */
    function execute(
        uint256 packetId,
        address localPlug,
        ISocket.MessageDetails calldata messageDetails_
    ) external override {
        if (!_executionManager__.isExecutor(msg.sender)) revert NotExecutor();
        if (messageExecuted[messageDetails_.msgId])
            revert MessageAlreadyExecuted();
        messageExecuted[messageDetails_.msgId] = true;

        uint256 remoteSlug = uint256(messageDetails_.msgId >> 224);

        PlugConfig storage plugConfig = _plugConfigs[
            (uint256(uint160(localPlug)) << 96) | remoteSlug
        ];

        feesEarned[remoteSlug][address(plugConfig.inboundSwitchboard__)][
            msg.sender
        ] += messageDetails_.executionFee;

        bytes32 packedMessage = _hasher__.packMessage(
            remoteSlug,
            plugConfig.siblingPlug,
            _chainSlug,
            localPlug,
            messageDetails_.msgId,
            messageDetails_.msgGasLimit,
            messageDetails_.executionFee,
            messageDetails_.payload
        );

        _verify(
            packetId,
            remoteSlug,
            packedMessage,
            plugConfig,
            messageDetails_.decapacitorProof
        );
        _execute(
            localPlug,
            remoteSlug,
            messageDetails_.msgGasLimit,
            messageDetails_.msgId,
            messageDetails_.payload
        );
    }

    function _verify(
        uint256 packetId,
        uint256 remoteChainSlug,
        bytes32 packedMessage,
        PlugConfig storage plugConfig,
        bytes memory decapacitorProof
    ) internal view {
        if (
            !ISwitchboard(plugConfig.inboundSwitchboard__).allowPacket(
                remoteRoots[packetId],
                packetId,
                remoteChainSlug,
                rootProposedAt[packetId]
            )
        ) revert VerificationFailed();

        if (
            !plugConfig.decapacitor__.verifyMessageInclusion(
                remoteRoots[packetId],
                packedMessage,
                decapacitorProof
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
            emit ExecutionSuccess(msgId);
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            messageExecuted[msgId] = false;
            emit ExecutionFailed(msgId, reason);
        } catch (bytes memory reason) {
            // catch failing assert()
            messageExecuted[msgId] = false;
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

    function isPacketProposed(uint256 packetId_) external view returns (bool) {
        return remoteRoots[packetId_] == bytes32(0) ? false : true;
    }

    function _getChainSlug(
        uint256 packetId_
    ) internal pure returns (uint256 chainSlug_) {
        chainSlug_ = uint32(packetId_ >> 224);
    }
}
