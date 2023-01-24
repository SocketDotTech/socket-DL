// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

// import "../interfaces/IVerifier.sol";
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
                _getChainSlug(packetId_),
                _chainSlug,
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
     * @param msgId message id packed with local plug, local chainSlug, remote ChainSlug and nonce
     * @param localPlug remote plug address
     * @param verifyParams_ the details needed for message verification
     */
    function execute(
        uint256 msgId,
        address localPlug,
        ISocket.VerificationParams calldata verifyParams_,
        ISocket.ExecutionParams calldata executeParams_
    ) external override nonReentrant {
        if (_executionManager__.isExecutor(msg.sender)) revert NotExecutor();
        if (messageExecuted[msgId]) revert MessageAlreadyExecuted();

        PlugConfig memory plugConfig = _plugConfigs[localPlug][
            verifyParams_.remoteChainSlug
        ];

        feesEarned[verifyParams_.remoteChainSlug][
            address(plugConfig.inboundSwitchboard__)
        ][msg.sender] += executeParams_.executionFee;

        bytes32 packedMessage = _hasher__.packMessage(
            verifyParams_.remoteChainSlug,
            plugConfig.siblingPlug,
            _chainSlug,
            localPlug,
            msgId,
            executeParams_.msgGasLimit,
            executeParams_.executionFee,
            executeParams_.payload
        );

        _verify(packedMessage, plugConfig, verifyParams_);
        _execute(
            localPlug,
            verifyParams_.remoteChainSlug,
            executeParams_.msgGasLimit,
            msgId,
            executeParams_.payload
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
            messageExecuted[msgId] = true;
            emit ExecutionSuccess(msgId);
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            emit ExecutionFailed(msgId, reason);
        } catch (bytes memory reason) {
            // catch failing assert()
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

    function getPacketStatus(uint256 packetId_) external view returns (bool) {
        return remoteRoots[packetId_] == bytes32(0) ? false : true;
    }

    function _getChainSlug(
        uint256 packetId_
    ) internal pure returns (uint256 chainSlug_) {
        chainSlug_ = uint32(packetId_ >> 224);
    }
}
