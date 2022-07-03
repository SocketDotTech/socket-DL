// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./BaseAccum.sol";

contract SingleAccum is BaseAccum {

    error PendingPacket();

    constructor(address socket_) BaseAccum(socket_) {}

    function addPacket(bytes32 packetHash) external override onlyRole(SOCKET_ROLE) {
        if (_roots[_nextBatch] != bytes32(0)) revert PendingPacket();
        _roots[_nextBatch] = packetHash;
        emit PacketAdded(packetHash, packetHash);
    }
}
