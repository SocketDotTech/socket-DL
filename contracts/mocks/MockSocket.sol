// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../Socket.sol";

contract MockAccessControl is Socket {
    error WrongRemotePlug();
    error WrongIntegrationType();

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
        PlugConfig memory srcPlugConfig = plugConfigs[msg.sender][
            remoteChainSlug_
        ];

        PlugConfig memory dstPlugConfig = plugConfigs[localPlug][_chainSlug];

        if (dstPlugConfig.remotePlug != msg.sender) revert WrongRemotePlug();
        if (dstPlugConfig.integrationType == srcPlugConfig.integrationType)
            revert WrongIntegrationType();

        _execute(
            srcPlugConfig.remotePlug,
            _chainSlug,
            msgGasLimit_,
            _messageCount++,
            payload_
        );
    }
}
