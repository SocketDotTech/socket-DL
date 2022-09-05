// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";
import "./interfaces/IAccumulator.sol";
import "./interfaces/IDeaccumulator.sol";
import "./interfaces/IVerifier.sol";
import "./interfaces/IPlug.sol";
import "./interfaces/INotary.sol";
import "./interfaces/IHasher.sol";

contract Socket is ISocket, AccessControl(msg.sender) {
    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    uint256 private immutable _chainId;

    // localPlug => remoteChainId => nonce
    mapping(address => mapping(uint256 => uint256)) private _nonces;

    // msgId => executorAddress
    mapping(uint256 => address) private executedPackedMessages;

    INotary private _notary;
    IHasher private _hasher;

    error NotAttested();

    event Executed(bool success, string result);

    constructor(
        uint256 chainId_,
        address hasher_,
        address notary_
    ) {
        _setHasher(hasher_);
        _chainId = chainId_;
        _notary = INotary(notary_);
    }

    function setNotary(address notary_) external onlyOwner {
        _notary = INotary(notary_);
    }

    function setHasher(address hasher_) external onlyOwner {
        _setHasher(hasher_);
    }

    function outbound(uint256 remoteChainId_, bytes calldata payload_)
        external
        override
    {
        OutboundConfig memory config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        uint256 nonce = _nonces[msg.sender][remoteChainId_]++;
        bytes32 packedMessage = _hasher.packMessage(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            nonce,
            payload_
        );

        IAccumulator(config.accum).addPackedMessage(packedMessage);
        emit MessageTransmitted(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            nonce,
            payload_
        );
    }

    function execute(
        uint256 remoteChainId_,
        address localPlug_,
        uint256 nonce_,
        address attester_,
        address remoteAccum_,
        uint256 packetId_,
        bytes calldata payload_,
        bytes calldata deaccumProof_
    ) external override {
        InboundConfig memory config = inboundConfigs[localPlug_][
            remoteChainId_
        ];

        bytes32 packedMessage = _hasher.packMessage(
            remoteChainId_,
            config.remotePlug,
            _chainId,
            localPlug_,
            nonce_,
            payload_
        );

        if (!_notary.isAttested(remoteAccum_, packetId_)) revert NotAttested();

        if (executedPackedMessages[packedMessage])
            revert MessageAlreadyExecuted();
        executedPackedMessages[packedMessage] = true;

        bytes32 root = _notary.getRemoteRoot(
            remoteChainId_,
            remoteAccum_,
            packetId_
        );
        if (
            !IDeaccumulator(config.deaccum).verifyMessageInclusion(
                root,
                packedMessage,
                deaccumProof_
            )
        ) revert InvalidProof();

        if (
            !IVerifier(config.verifier).verifyRoot(
                attester_,
                remoteChainId_,
                remoteAccum_,
                packetId_,
                root
            )
        ) revert VerificationFailed();

        try IPlug(localPlug_).inbound(payload_) {
            emit Executed(true, "");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            emit Executed(false, reason);
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

    function _setHasher(address hasher_) private {
        _hasher = IHasher(hasher_);
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function hasher() external view returns (address) {
        return address(_hasher);
    }

    function getMessageStatus(bytes32 packedMessage_)
        public
        view
        returns (bool)
    {
        return executedPackedMessages[packedMessage_];
    }
}
