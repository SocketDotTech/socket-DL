// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./BaseAccum.sol";

contract SingleAccum is BaseAccum {
    uint256 internal _nextBatchToFill;

    error PendingPacket();

    constructor(address socket_) BaseAccum(socket_) {}

    function addPacket(bytes32 packetHash)
        external
        override
        onlyRole(SOCKET_ROLE)
    {
        _roots[_nextBatchToFill] = packetHash;
        emit PacketAdded(packetHash, _roots[_nextBatchToFill]);
        _nextBatchToFill++;
    }
}
