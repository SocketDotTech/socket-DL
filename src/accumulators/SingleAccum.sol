// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

import "../interfaces/IAccumulator.sol";
import "../utils/AccessControl.sol";

contract SingleAcc is IAccumulator, AccessControl(msg.sender) {
    bytes32 private _root;
    uint256 private _batchId;
    mapping(uint256 => bytes32) private _roots;

    error PendingPacket();

    function addPacket(bytes32 packetHash) external override onlyPerm(SOCKET_ROLE) {
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
    function incrementBatch() external override onlyPerm(NOTARY_ROLE) returns (bytes32) {
        bytes32 root = _roots[_batchId];
        emit BatchComplete(root, _batchId++);
        return root;
    }
}
