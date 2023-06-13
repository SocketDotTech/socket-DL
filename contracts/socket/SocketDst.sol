// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IPlug.sol";
import "./SocketBase.sol";

/**
 * @title SocketDst
 * @dev SocketDst is an abstract contract that inherits from SocketBase and
 * provides additional functionality for message execution, packet proposal, and verification.
 * It manages the mapping of message execution status, packet ID roots, and root proposed
 * timestamps. It emits events for packet proposal and root updates.
 * It also includes functions for message execution and verification, as well as a function
 * to check if a packet has been proposed.
 */
abstract contract SocketDst is SocketBase {
    /*
     * @dev Error emitted when a packet has not been proposed
     */
    error PacketNotProposed();
    /*
     * @dev Error emitted when a packet id is invalid
     */
    error InvalidPacketId();

    /**
     * @dev Error emitted when proof is invalid
     */
    error InvalidProof();

    /**
     * @dev Error emitted when a message has already been executed
     */
    error MessageAlreadyExecuted();
    /**
     * @dev Error emitted when the attester is not valid
     */
    error NotExecutor();
    /**
     * @dev Error emitted when verification fails
     */
    error VerificationFailed();
    /**
     * @dev Error emitted when source slugs deduced from packet id and msg id don't match
     */
    error ErrInSourceValidation();

    /**
     * @dev msgId => message status mapping
     */
    mapping(bytes32 => bool) public messageExecuted;
    /**
     * @dev capacitorAddr|chainSlug|packetId => proposalCount => packetIdRoots
     */
    mapping(bytes32 => mapping(uint256 => bytes32))
        public
        override packetIdRoots;
    /**
     * @dev packetId => proposalCount => proposalTimestamp
     */
    mapping(bytes32 => mapping(uint256 => uint256)) public rootProposedAt;

    /**
     * @dev packetId => proposalCountCount
     */
    mapping(bytes32 => uint256) public proposalCountCount;

    /**
     * @notice emits the packet details when proposed at remote
     * @param transmitter address of transmitter
     * @param packetId packet id
     * @param proposalCount proposal id
     * @param root packet root
     */
    event PacketProposed(
        address indexed transmitter,
        bytes32 indexed packetId,
        uint256 proposalCount,
        bytes32 root
    );

    /**
     * @notice emits the root details when root is replaced by owner
     * @param packetId packet id
     * @param oldRoot old root
     * @param newRoot old root
     */
    event PacketRootUpdated(bytes32 packetId, bytes32 oldRoot, bytes32 newRoot);

    /**
     * @dev Function to propose a packet
     * @notice the signature is validated if it belongs to transmitter or not
     * @param packetId_ packet id
     * @param root_ packet root
     * @param signature_ signature
     */
    function propose(
        bytes32 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external override {
        if (packetId_ == bytes32(0)) revert InvalidPacketId();

        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                uint32(_decodeSlug(packetId_)),
                keccak256(abi.encode(version, chainSlug, packetId_, root_)),
                signature_
            );

        if (!isTransmitter) revert InvalidTransmitter();

        packetIdRoots[packetId_][proposalCountCount[packetId_]] = root_;
        rootProposedAt[packetId_][proposalCountCount[packetId_]] = block
            .timestamp;

        emit PacketProposed(
            transmitter,
            packetId_,
            proposalCountCount[packetId_]++,
            root_
        );
    }

    /**
     * @notice executes a message, fees will go to recovered executor address
     * @param packetId_ packet id
     * @param proposalCount_ proposal id
     * @param messageDetails_ the details needed for message verification
     */
    function execute(
        bytes32 packetId_,
        uint256 proposalCount_,
        ISocket.MessageDetails calldata messageDetails_,
        bytes memory signature_
    ) external payable override {
        if (messageExecuted[messageDetails_.msgId])
            revert MessageAlreadyExecuted();
        messageExecuted[messageDetails_.msgId] = true;

        if (packetId_ == bytes32(0)) revert InvalidPacketId();
        if (packetIdRoots[packetId_][proposalCount_] == bytes32(0))
            revert PacketNotProposed();

        uint32 remoteSlug = _decodeSlug(messageDetails_.msgId);
        if (_decodeSlug(packetId_) != remoteSlug)
            revert ErrInSourceValidation();

        address localPlug = _decodePlug(messageDetails_.msgId);

        PlugConfig storage plugConfig = _plugConfigs[localPlug][remoteSlug];

        bytes32 packedMessage = hasher__.packMessage(
            remoteSlug,
            plugConfig.siblingPlug,
            chainSlug,
            localPlug,
            messageDetails_
        );

        (address executor, bool isValidExecutor) = executionManager__
            .isExecutor(packedMessage, signature_);
        if (!isValidExecutor) revert NotExecutor();

        _verify(
            packetId_,
            proposalCount_,
            remoteSlug,
            packedMessage,
            plugConfig,
            messageDetails_.decapacitorProof,
            messageDetails_.extraParams
        );
        _execute(executor, localPlug, remoteSlug, messageDetails_);
    }

    function _verify(
        bytes32 packetId_,
        uint256 proposalCount_,
        uint32 remoteChainSlug_,
        bytes32 packedMessage_,
        PlugConfig storage plugConfig_,
        bytes memory decapacitorProof_,
        bytes32 extraParams_
    ) internal view {
        if (
            !ISwitchboard(plugConfig_.inboundSwitchboard__).allowPacket(
                packetIdRoots[packetId_][proposalCount_],
                packetId_,
                proposalCount_,
                uint32(remoteChainSlug_),
                rootProposedAt[packetId_][proposalCount_]
            )
        ) revert VerificationFailed();

        if (
            !plugConfig_.decapacitor__.verifyMessageInclusion(
                packetIdRoots[packetId_][proposalCount_],
                packedMessage_,
                decapacitorProof_
            )
        ) revert InvalidProof();

        executionManager__.verifyParams(extraParams_, msg.value);
    }

    /**
     * This function assumes localPlug_ will have code while executing. As the message
     * execution failure is not blocking the system, it is not necessary to check if
     * code exists in the given address.
     * @dev distribution of msg.value in case of inbound failure is to be decided.
     */
    function _execute(
        address executor_,
        address localPlug_,
        uint32 remoteChainSlug_,
        ISocket.MessageDetails memory messageDetails_
    ) internal {
        try
            IPlug(localPlug_).inbound{
                gas: messageDetails_.msgGasLimit,
                value: msg.value
            }(remoteChainSlug_, messageDetails_.payload)
        {
            executionManager__.updateExecutionFees(
                executor_,
                messageDetails_.executionFee,
                messageDetails_.msgId
            );
            emit ExecutionSuccess(messageDetails_.msgId);
        } catch Error(string memory reason) {
            if (address(this).balance > 0) {
                (bool success, ) = msg.sender.call{
                    value: address(this).balance
                }("");
                require(success, "Fund Transfer Failed");
            }
            // catch failing revert() and require()
            messageExecuted[messageDetails_.msgId] = false;
            emit ExecutionFailed(messageDetails_.msgId, reason);
        } catch (bytes memory reason) {
            if (address(this).balance > 0) {
                (bool success, ) = msg.sender.call{
                    value: address(this).balance
                }("");
                require(success, "Fund Transfer Failed");
            }
            // catch failing assert()
            messageExecuted[messageDetails_.msgId] = false;
            emit ExecutionFailedBytes(messageDetails_.msgId, reason);
        }
    }

    /**
     * @dev Checks whether the specified packet has been proposed.
     * @param packetId_ The ID of the packet to check.
     * @param packetId_ The proposal ID of the packetId to check.
     * @return A boolean indicating whether the packet has been proposed or not.
     */
    function isPacketProposed(
        bytes32 packetId_,
        uint256 proposalCount_
    ) external view returns (bool) {
        return
            packetIdRoots[packetId_][proposalCount_] == bytes32(0)
                ? false
                : true;
    }

    /**
     * @dev Decodes the plug address from a given message id.
     * @param id_ The ID of the msg to decode the plug from.
     * @return plug_ The address of sibling plug decoded from the message ID.
     */
    function _decodePlug(bytes32 id_) internal pure returns (address plug_) {
        plug_ = address(uint160(uint256(id_) >> 64));
    }

    /**
     * @dev Decodes the chain ID from a given packet/message ID.
     * @param id_ The ID of the packet/msg to decode the chain slug from.
     * @return chainSlug_ The chain slug decoded from the packet/message ID.
     */
    function _decodeSlug(
        bytes32 id_
    ) internal pure returns (uint32 chainSlug_) {
        chainSlug_ = uint32(uint256(id_) >> 224);
    }
}
