// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./interfaces/ISocket.sol";
import "./utils/AccessControl.sol";
import "./interfaces/IAccumulator.sol";
import "./interfaces/IDeaccumulator.sol";
import "./interfaces/IVerifier.sol";
import "./interfaces/IPlug.sol";
import "./interfaces/INotary.sol";

contract Socket is ISocket, AccessControl(msg.sender) {
    // localPlug => remoteChainId => OutboundConfig
    mapping(address => mapping(uint256 => OutboundConfig))
        public outboundConfigs;

    // localPlug => remoteChainId => InboundConfig
    mapping(address => mapping(uint256 => InboundConfig)) public inboundConfigs;

    uint256 private immutable _chainId;

    // localPlug => remoteChainId => nonce
    mapping(address => mapping(uint256 => uint256)) private _nonces;

    // packedMessage => executeStatus
    mapping(bytes32 => bool) private _executedMessages;

    // localPlug => remoteChainId => nextNonce
    mapping(address => mapping(uint256 => uint256)) private _nextNonces;

    INotary private _notary;

    error NotAttested();

    constructor(uint256 chainId_) {
        _chainId = chainId_;
    }

    function setNotary(address notary_) public onlyOwner {
        _notary = INotary(notary_);
    }

    function outbound(uint256 remoteChainId_, bytes calldata payload_)
        external
        override
    {
        OutboundConfig memory config = outboundConfigs[msg.sender][
            remoteChainId_
        ];
        uint256 nonce = _nonces[msg.sender][remoteChainId_]++;
        bytes32 packedMessage = _packMessage(
            _chainId,
            msg.sender,
            remoteChainId_,
            config.remotePlug,
            nonce,
            payload_
        );

        IAccumulator(config.accum).addMessage(packedMessage);
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

        bytes32 packedMessage = _packMessage(
            remoteChainId_,
            config.remotePlug,
            _chainId,
            localPlug_,
            nonce_,
            payload_
        );

        if (!_notary.isAttested(remoteAccum_, packetId_)) revert NotAttested();

        if (_executedMessages[packedMessage]) revert MessageAlreadyExecuted();
        _executedMessages[packedMessage] = true;

        if (
            config.isSequential &&
            nonce_ != _nextNonces[localPlug_][remoteChainId_]++
        ) revert InvalidNonce();

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
        ) revert DappVerificationFailed();

        IPlug(localPlug_).inbound(payload_);
    }

    function _packMessage(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 nonce,
        bytes calldata payload
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    srcChainId,
                    srcPlug,
                    dstChainId,
                    dstPlug,
                    nonce,
                    payload
                )
            );
    }

    function dropMessages(uint256 remoteChainId_, uint256 count_) external {
        _nextNonces[msg.sender][remoteChainId_] += count_;
    }

    function chainId() external view returns (uint256) {
        return _chainId;
    }

    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_,
        bool isSequential_
    ) external override {
        InboundConfig storage config = inboundConfigs[msg.sender][
            remoteChainId_
        ];
        config.remotePlug = remotePlug_;
        config.deaccum = deaccum_;
        config.verifier = verifier_;
        config.isSequential = isSequential_;

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
}
