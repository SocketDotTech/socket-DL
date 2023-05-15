// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "../utils/AccessControl.sol";
import "../libraries/RescueFundsLib.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";

/**
 * @title BaseCapacitor
 * @dev Abstract base contract for the Capacitors. Implements shared functionality and provides
 * access control.
 */
abstract contract BaseCapacitor is ICapacitor, AccessControl {
    /// an incrementing count for each new packet created
    uint64 internal _nextPacketCount;

    /// tracks the last packet sealed
    uint64 internal _nextSealCount;

    address public immutable socket;

    /// maps the packet count with the root hash generated while adding message
    mapping(uint64 => bytes32) internal _roots;

    error NoPendingPacket();
    error OnlySocket();

    /**
     * @dev Throws if called by any account other than the socket.
     */
    modifier onlySocket() {
        if (msg.sender != socket) revert OnlySocket();

        _;
    }

    /**
     * @dev Initializes the contract with the specified socket address.
     * @param socket_ The address of the socket contract.
     * @param owner_ The address of the owner of the capacitor contract.
     */
    constructor(address socket_, address owner_) AccessControl(owner_) {
        socket = socket_;
    }

    /**
     * @dev Seals the next pending packet and returns its root hash and packet count.
     * @dev we use seal packet count to make sure there is no scope of censorship and all the packets get sealed.
     * @return The root hash and packet count of the sealed packet.
     */
    function sealPacket(
        uint256
    ) external virtual override onlySocket returns (bytes32, uint64) {
        uint64 packetCount = _nextSealCount++;
        if (_roots[packetCount] == bytes32(0)) revert NoPendingPacket();

        bytes32 root = _roots[packetCount];
        return (root, packetCount);
    }

    /**
     * @dev Returns the root hash and packet count of the next pending packet to be sealed.
     * @return The root hash and packet count of the next pending packet.
     */
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

    /**
     * @dev Returns the root hash of the packet with the specified count.
     * @param count_ The count of the packet.
     * @return The root hash of the packet.
     */
    function getRootByCount(
        uint64 count_
    ) external view virtual override returns (bytes32) {
        return _roots[count_];
    }

    /**
     * @dev Returns the count of the latest packet.
     * @return The count of the latest packet.
     */
    function getLatestPacketCount() external view returns (uint256) {
        return _nextPacketCount == 0 ? 0 : _nextPacketCount - 1;
    }

    /**
     * @dev Rescues funds from the contract.
     * @param token_ The address of the token to rescue.
     * @param userAddress_ The address of the user to rescue tokens for.
     * @param amount_ The amount of tokens to rescue.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
