// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/IAccumulator.sol";
import "../utils/AccessControl.sol";

abstract contract BaseAccum is IAccumulator, AccessControl(msg.sender) {
    uint256 internal _nextPacket;
    mapping(uint256 => bytes32) internal _roots;

    constructor(address socket_) {
        _grantRole(SOCKET_ROLE, socket_);
    }

    function getNextPacket()
        external
        view
        virtual
        override
        returns (bytes32, uint256)
    {
        return (_roots[_nextPacket], _nextPacket);
    }

    function getRootById(uint256 id)
        external
        view
        virtual
        override
        returns (bytes32)
    {
        return _roots[id];
    }

    function sealPacket()
        external
        virtual
        override
        onlyRole(SOCKET_ROLE)
        returns (bytes32, uint256)
    {
        bytes32 root = _roots[_nextPacket];
        emit PacketComplete(root, _nextPacket);
        return (root, _nextPacket++);
    }
}
