// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface ISocket {
    /**
     * @notice emits the message details when a new message arrives at outbound
     * @param localChainSlug local chain slug
     * @param localPlug local plug address
     * @param dstChainSlug remote chain slug
     * @param dstPlug remote plug address
     * @param msgId message id packed with remoteChainSlug and nonce
     * @param msgGasLimit gas limit needed to execute the inbound at remote
     * @param fees fees provided by msg sender
     * @param payload the data which will be used by inbound at remote
     */
    event MessageTransmitted(
        uint256 localChainSlug,
        address localPlug,
        uint256 dstChainSlug,
        address dstPlug,
        uint256 msgId,
        uint256 msgGasLimit,
        uint256 fees,
        bytes payload
    );

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     */
    event ExecutionSuccess(uint256 msgId);

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     * @param result if message reverts, returns the revert message
     */
    event ExecutionFailed(uint256 msgId, string result);

    /**
     * @notice emits the error message in bytes after inbound call
     * @param msgId msg id which is executed
     * @param result if message reverts, returns the revert message in bytes
     */
    event ExecutionFailedBytes(uint256 msgId, bytes result);

    /**
     * @notice emits the config set by a plug for a remoteChainSlug
     * @param remotePlug address of plug on remote chain
     * @param remoteChainSlug remote chain slug
     * @param inboundIntegrationType inbound integration type (set in socket config, plug can choose any)
     * @param outboundIntegrationType outbound integration type (set in socket config, plug can choose any)
     */
    event PlugConfigSet(
        address remotePlug,
        uint256 remoteChainSlug,
        bytes32 inboundIntegrationType,
        bytes32 outboundIntegrationType
    );

    /**
     * @notice emits when a msg is retried with updated fees
     * @param msgId_ msg id to be retried
     * @param newMsgGasLimit_ new gas limit to execute a message
     * @param fees_ additional fees sent
     */
    event MessageRetried(
        uint256 msgId_,
        uint256 newMsgGasLimit_,
        uint256 fees_
    );

    /**
     * @notice emits when a new signature verifier contract is set
     * @param signatureVerifier_ address of new verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier_);

    /**
     * @notice emits when a new transmitManager contract is set
     * @param transmitManager_ address of new transmitManager contract
     */
    event TransmitManager(address transmitManager_);

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
    ) external payable;

    struct VerificationParams {
        uint256 remoteChainSlug;
        uint256 packetId;
        bytes deaccumProof;
    }

    /**
     * @notice executes a message
     * @param msgGasLimit gas limit needed to execute the inbound at remote
     * @param msgId message id packed with remoteChainSlug and nonce
     * @param localPlug local plug address
     * @param payload the data which is needed by plug at inbound call on remote
     * @param verifyParams_ the details needed for message verification
     */
    function execute(
        uint256 msgGasLimit,
        uint256 msgId,
        address localPlug,
        bytes calldata payload,
        ISocket.VerificationParams calldata verifyParams_
    ) external;

    /**
     * @notice sets the config specific to the plug
     * @param remoteChainSlug_ the remote chain slug
     * @param remotePlug_ address of plug present at remote chain to call inbound
     * @param inboundIntegrationType_ the name of config to use for receiving messages
     * @param outboundIntegrationType_ the name of config to use for sending messages
     */
    function setPlugConfig(
        uint256 remoteChainSlug_,
        address remotePlug_,
        string memory inboundIntegrationType_,
        string memory outboundIntegrationType_
    ) external;

    // TODO: retry
    // function retry(uint256 msgId_, uint256 newMsgGasLimit_) external payable;

    // function retryExecute(
    //     uint256 newMsgGasLimit,
    //     uint256 msgId,
    //     uint256 msgGasLimit,
    //     address localPlug,
    //     bytes calldata payload,
    //     ISocket.VerificationParams calldata verifyParams_
    // ) external;
}
