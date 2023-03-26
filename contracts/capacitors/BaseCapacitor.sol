// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "../utils/AccessControlExtended.sol";
import "../libraries/RescueFundsLib.sol";

abstract contract BaseCapacitor is ICapacitor, AccessControlExtended {
    // keccak256("SOCKET_ROLE")
    bytes32 public constant SOCKET_ROLE =
        0x9626cdfde87fcc60a5069beda7850c84f848fb1b20dab826995baf7113491456;

    /// an incrementing id for each new packet created
    uint64 internal _nextPacketCount;
    uint64 internal _nextSealCount;

    address public immutable socket;

    /// maps the packet id with the root hash generated while adding message
    mapping(uint64 => bytes32) internal _roots;

    error NoPendingPacket();
    error OnlySocket();

    modifier onlySocket() {
        if (msg.sender != socket) revert OnlySocket();

        _;
    }

    /**
     * @notice initialises the contract with socket address
     */
    constructor(address socket_, address owner_) AccessControlExtended(owner_) {
        socket = socket_;
    }

    /// returns the latest packet details to be sealed
    /// @inheritdoc ICapacitor
    function getNextPacketToBeSealed()
        external
        view
        virtual
        override
        returns (bytes32, uint64)
    {
        uint64 toSeal = _nextSealCount;
        return (_roots[toSeal], toSeal);
    }

    /// returns the root of packet for given id
    /// @inheritdoc ICapacitor
    function getRootByCount(
        uint64 id_
    ) external view virtual override returns (bytes32) {
        return _roots[id_];
    }

    function getLatestPacketCount() external view returns (uint256) {
        return _nextPacketCount == 0 ? 0 : _nextPacketCount - 1;
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
