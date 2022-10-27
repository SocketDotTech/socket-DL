// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IAccumulator.sol";
import "../utils/AccessControl.sol";

abstract contract BaseAccum is IAccumulator, AccessControl(msg.sender) {
    bytes32 public constant SOCKET_ROLE = keccak256("SOCKET_ROLE");
    bytes32 public constant NOTARY_ROLE = keccak256("NOTARY_ROLE");
    uint256 public immutable remoteChainSlug;

    /// an incrementing id for each new packet created
    uint256 internal _packets;
    uint256 internal _sealedPackets;

    /// maps the packet id with the root hash generated while adding message
    mapping(uint256 => bytes32) internal _roots;

    error NoPendingPacket();

    /**
     * @notice initialises the contract with socket and notary addresses
     */
    constructor(
        address socket_,
        address notary_,
        uint32 remoteChainSlug_
    ) {
        _setSocket(socket_);
        _setNotary(notary_);

        remoteChainSlug = remoteChainSlug_;
    }

    /// @inheritdoc IAccumulator
    function sealPacket()
        external
        virtual
        override
        onlyRole(NOTARY_ROLE)
        returns (
            bytes32,
            uint256,
            uint256
        )
    {
        uint256 packetId = _sealedPackets;

        if (_roots[packetId] == bytes32(0)) revert NoPendingPacket();
        bytes32 root = _roots[packetId];
        _sealedPackets++;

        emit PacketComplete(root, packetId);
        return (root, packetId, remoteChainSlug);
    }

    function setSocket(address socket_) external onlyOwner {
        _setSocket(socket_);
    }

    function setNotary(address notary_) external onlyOwner {
        _setNotary(notary_);
    }

    function _setSocket(address socket_) private {
        _grantRole(SOCKET_ROLE, socket_);
    }

    function _setNotary(address notary_) private {
        _grantRole(NOTARY_ROLE, notary_);
    }

    /// returns the latest packet details to be sealed
    /// @inheritdoc IAccumulator
    function getNextPacketToBeSealed()
        external
        view
        virtual
        override
        returns (bytes32, uint256)
    {
        uint256 toSeal = _sealedPackets;
        return (_roots[toSeal], toSeal);
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

    function getLatestPacketId() external view returns (uint256) {
        return _packets == 0 ? 0 : _packets - 1;
    }
}
