// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/IAccumulator.sol";
import "../utils/AccessControl.sol";

abstract contract BaseAccum is IAccumulator, AccessControl(msg.sender) {
    bytes32 public SOCKET_ROLE = keccak256("SOCKET_ROLE");
    bytes32 public NOTARY_ROLE = keccak256("NOTARY_ROLE");

    /// an incrementing id for each new packet created
    uint256 internal _nextPacket;

    /// maps the packet id with the root hash generated while adding message
    mapping(uint256 => bytes32) internal _roots;

    error NoPendingPacket();

    /**
     * @notice initialises the contract with socket and notary addresses
     */
    constructor(address socket_, address notary_) {
        _setSocket(socket_);
        _setNotary(notary_);
    }

    /// @inheritdoc IAccumulator
    function sealPacket()
        external
        virtual
        override
        onlyRole(NOTARY_ROLE)
        returns (bytes32, uint256)
    {
        if (_roots[_nextPacket] == bytes32(0)) revert NoPendingPacket();
        bytes32 root = _roots[_nextPacket];

        emit PacketComplete(root, _nextPacket);
        return (root, _nextPacket++);
    }

    function _setSocket(address socket_) private {
        _grantRole(SOCKET_ROLE, socket_);
        emit SocketSet(socket_);
    }

    function _setNotary(address notary_) private {
        _grantRole(NOTARY_ROLE, notary_);
        emit NotarySet(notary_);
    }

    /// returns the latest packet details
    /// @inheritdoc IAccumulator
    function getNextPacket()
        external
        view
        virtual
        override
        returns (bytes32, uint256)
    {
        return (_roots[_nextPacket], _nextPacket);
    }

    /// returns the root of packet for given id
    /// @inheritdoc IAccumulator
    function getRootById(uint256 id)
        external
        view
        virtual
        override
        returns (bytes32)
    {
        return _roots[id];
    }
}
