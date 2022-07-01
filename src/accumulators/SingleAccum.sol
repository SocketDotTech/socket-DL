// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

import "../interfaces/IAccumulator.sol";
import "../utils/AccessControl.sol";

contract SingleAccum is IAccumulator, AccessControl(msg.sender) {
    bytes32 private _root;
    uint256 private _batchId;
    mapping(uint256 => bytes32) private _roots;

    error PendingPacket();

    constructor(address socket_) {
        _grantRole(SOCKET_ROLE, socket_);
    }

    function addPacket(bytes32 packetHash) external override onlyRole(SOCKET_ROLE) {
        if (_roots[_batchId] != bytes32(0)) revert PendingPacket();
        _roots[_batchId] = packetHash;
        emit PacketAdded(packetHash, packetHash);
    }

    function getNextBatch() external view override returns (bytes32, uint256) {
        return (_roots[_batchId], _batchId);
    }

    function getRootById(uint256 id) external view override returns (bytes32) {
        return _roots[id];
    }

    // caller only Notary
    function sealBatch() external override onlyRole(SOCKET_ROLE) returns (bytes32, uint256) {
        bytes32 root = _roots[_batchId];
        emit BatchComplete(root, _batchId);
        return (root, _batchId++);
    }
}
