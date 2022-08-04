// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./BaseAccum.sol";

contract SingleAccum is BaseAccum {
    error PendingPacket();

    constructor(address socket_) BaseAccum(socket_) {}

    function addMessage(bytes32 packedMessage)
        external
        override
        onlyRole(SOCKET_ROLE)
    {
        if (_roots[_nextPacket] != bytes32(0)) revert PendingPacket();
        _roots[_nextPacket] = packedMessage;
        emit MessageAdded(packedMessage, packedMessage);
    }
}
