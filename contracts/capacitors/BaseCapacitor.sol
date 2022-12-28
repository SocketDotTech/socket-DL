// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "../utils/AccessControl.sol";

abstract contract BaseCapacitor is ICapacitor, AccessControl(msg.sender) {
    bytes32 public constant SOCKET_ROLE = keccak256("SOCKET_ROLE");

    /// an incrementing id for each new packet created
    uint256 internal _packets;
    uint256 internal _sealedPackets;

    /// maps the packet id with the root hash generated while adding message
    mapping(uint256 => bytes32) internal _roots;

    error NoPendingPacket();

    /**
     * @notice initialises the contract with socket address
     */
    constructor(address socket_) {
        _setSocket(socket_);
    }

    function setSocket(address socket_) external onlyOwner {
        _setSocket(socket_);
    }

    function _setSocket(address socket_) private {
        _grantRole(SOCKET_ROLE, socket_);
    }

    /// returns the latest packet details to be sealed
    /// @inheritdoc ICapacitor
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
    /// @inheritdoc ICapacitor
    function getRootById(
        uint256 id
    ) external view virtual override returns (bytes32) {
        return _roots[id];
    }

    function getLatestPacketId() external view returns (uint256) {
        return _packets == 0 ? 0 : _packets - 1;
    }
}
