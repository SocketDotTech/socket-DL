// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseAccum.sol";

contract SingleAccum is BaseAccum {
    error PendingPacket();

    /**
     * @notice initialises the contract with socket and notary addresses
     */
    constructor(address socket_, address notary_) BaseAccum(socket_, notary_) {}

    /// adds the packed message to a packet
    /// @inheritdoc IAccumulator
    function addPackedMessage(bytes32 packedMessage)
        external
        override
        onlyRole(SOCKET_ROLE)
    {
        if (_roots[_nextPacket] != bytes32(0)) revert PendingPacket();
        _roots[_nextPacket] = packedMessage;
        emit MessageAdded(packedMessage, _nextPacket, packedMessage);
    }
}
