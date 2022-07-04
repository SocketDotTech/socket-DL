// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

import "../interfaces/IAccumulator.sol";
import "../utils/AccessControl.sol";

abstract contract BaseAccum is IAccumulator, AccessControl(msg.sender) {
    uint256 internal _nextBatch;
    mapping(uint256 => bytes32) internal _roots;

    constructor(address socket_) {
        _grantRole(SOCKET_ROLE, socket_);
    }

    function getNextBatch() external view override virtual returns (bytes32, uint256) {
        return (_roots[_nextBatch], _nextBatch);
    }

    function getRootById(uint256 id) external view override virtual returns (bytes32) {
        return _roots[id];
    }

    function sealBatch() external override virtual onlyRole(SOCKET_ROLE) returns (bytes32, uint256) {
        bytes32 root = _roots[_nextBatch];
        emit BatchComplete(root, _nextBatch);
        return (root, _nextBatch++);
    }
}
