// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/ISocket.sol";
import "./interfaces/IAccumulator.sol";
import "./interfaces/IDeaccumulator.sol";
import "./interfaces/IVerifier.sol";
import "./interfaces/IPlug.sol";
import "./interfaces/IHasher.sol";
import "./utils/AccessControl.sol";

contract Socket is ISocket, AccessControl(msg.sender) {
    enum MessageStatus {
        NOT_EXECUTED,
        SUCCESS,
        FAILED
    }

    uint256 private immutable _chainId;

    bytes32 private constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    // localPlug => remoteChainId => nonce
    mapping(address => mapping(uint256 => uint256)) private _nonces;

    // msgId => executorAddress
    mapping(uint256 => address) private executedPackedMessages;

    // msgId => message status
    mapping(uint256 => MessageStatus) private _messagesStatus;

    IHasher public hasher;
    IVault public override vault;

    constructor(
        uint256 chainId_,
        address hasher_,
        address vault_
    ) {
        _setHasher(hasher_);
        _chainId = chainId_;
        vault = IVault(vault_);
    }

    function setHasher(address hasher_) external onlyOwner {
        _setHasher(hasher_);
    }

    function outbound(
        uint256 remoteChainId_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable override {
        OutboundConfig memory config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        uint256 nonce = _nonces[msg.sender][remoteChainId_]++;
        uint256 msgId = (uint64(remoteChainId_) << 32) | nonce;

        vault.deductFee{value: msg.value}(remoteChainId_, msgGasLimit_);

        bytes32 packedMessage = hasher.packMessage(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            msgId,
            msgGasLimit_,
            payload_
        );

        IAccumulator(config.accum).addPackedMessage(packedMessage);
        emit MessageTransmitted(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            msgId,
            msgGasLimit_,
            payload_
        );
    }

    function execute(ISocket.ExecuteParams calldata executeParams_)
        external
        override
    {
        if (!_hasRole(EXECUTOR_ROLE, msg.sender)) revert ExecutorNotFound();

        if (executedPackedMessages[executeParams_.msgId] != address(0))
            revert MessageAlreadyExecuted();

        executedPackedMessages[executeParams_.msgId] = msg.sender;

        InboundConfig memory config = inboundConfigs[executeParams_.localPlug][
            executeParams_.remoteChainId
        ];

        (bool isVerified, bytes32 root) = IVerifier(config.verifier).verifyRoot(
            executeParams_.remoteAccum,
            executeParams_.remoteChainId,
            executeParams_.packetId
        );

        if (!isVerified) revert VerificationFailed();

        bytes32 packedMessage = hasher.packMessage(
            executeParams_.remoteChainId,
            config.remotePlug,
            _chainId,
            executeParams_.localPlug,
            executeParams_.msgId,
            executeParams_.msgGasLimit,
            executeParams_.payload
        );

        if (
            !IDeaccumulator(config.deaccum).verifyMessageInclusion(
                root,
                packedMessage,
                executeParams_.deaccumProof
            )
        ) revert InvalidProof();

        try
            IPlug(executeParams_.localPlug).inbound{
                gas: executeParams_.msgGasLimit
            }(executeParams_.payload)
        {
            _messagesStatus[executeParams_.msgId] = MessageStatus.SUCCESS;
            emit Executed(true, "");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            _messagesStatus[executeParams_.msgId] = MessageStatus.FAILED;
            emit Executed(false, reason);
        } catch (bytes memory reason) {
            // catch failing assert()
            _messagesStatus[executeParams_.msgId] = MessageStatus.FAILED;
            emit ExecutedBytes(false, reason);
        }
    }

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_
    ) external override {
        InboundConfig storage config = inboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.remotePlug = remotePlug_;
        config.deaccum = deaccum_;
        config.verifier = verifier_;

        // TODO: emit event
    }

    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external override {
        OutboundConfig storage config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.accum = accum_;
        config.remotePlug = remotePlug_;

        // TODO: emit event
    }

    /**
     * @notice adds an executor
     * @param executor_ executor address
     */
    function grantExecutorRole(address executor_) external onlyOwner {
        _grantRole(EXECUTOR_ROLE, executor_);
    }

    /**
     * @notice removes an executor from `remoteChainId_` chain list
     * @param executor_ executor address
     */
    function revokeExecutorRole(address executor_) external onlyOwner {
        _revokeRole(EXECUTOR_ROLE, executor_);
    }

    function _setHasher(address hasher_) private {
        hasher = IHasher(hasher_);
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function getMessageStatus(uint256 msgId_)
        external
        view
        returns (MessageStatus)
    {
        return _messagesStatus[msgId_];
    }

    // TODO:
    // function updateSocket() external onlyOwner {
    //     // transfer ownership of connected contracts to new socket
    //     // update addresses everywhere
    // }
}
