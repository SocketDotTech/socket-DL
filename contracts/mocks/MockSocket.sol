// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../Socket.sol";

contract MockAccessControl is Socket {
    constructor(
        uint32 chainSlug_,
        address hasher_,
        address vault_
    ) Socket(chainSlug_, hasher_, vault_) {}

    function outbound(
        uint256 remoteChainSlug_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable override {
        PlugConfig memory plugConfig = plugConfigs[msg.sender][
            remoteChainSlug_
        ];

        uint256 msgId = (uint256(uint32(_chainSlug)) << 224) | _messageCount++;

        emit MessageTransmitted(
            _chainSlug,
            msg.sender,
            remoteChainSlug_,
            plugConfig.remotePlug,
            msgId,
            msgGasLimit_,
            msg.value,
            payload_
        );

        ISocket.VerificationParams memory verifyParams;
        verifyParams.deaccumProof = bytes("");
        verifyParams.packetId = 0;
        verifyParams.remoteChainSlug = _chainSlug;

        execute(
            msgGasLimit_,
            msgId,
            plugConfig.remotePlug,
            payload_,
            verifyParams
        );
    }

    function execute(
        uint256 msgGasLimit,
        uint256 msgId,
        address localPlug,
        bytes calldata payload,
        ISocket.VerificationParams memory verifyParams_
    ) public override nonReentrant {
        if (msg.sender != address(this)) revert ExecutorNotFound();
        if (executor[msgId] != address(0)) revert MessageAlreadyExecuted();
        executor[msgId] = msg.sender;

        PlugConfig memory plugConfig = plugConfigs[localPlug][
            verifyParams_.remoteChainSlug
        ];

        _execute(
            localPlug,
            verifyParams_.remoteChainSlug,
            msgGasLimit,
            msgId,
            payload
        );
    }
}
