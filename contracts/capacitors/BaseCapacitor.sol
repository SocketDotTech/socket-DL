// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/ICapacitor.sol";
import "../utils/AccessControl.sol";
import "../libraries/SafeTransferLib.sol";

abstract contract BaseCapacitor is ICapacitor, AccessControl(msg.sender) {
    using SafeTransferLib for IERC20;

    // keccak256("SOCKET_ROLE")
    bytes32 public constant SOCKET_ROLE =
        0x9626cdfde87fcc60a5069beda7850c84f848fb1b20dab826995baf7113491456;

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

    function getLatestPacketCount() external view returns (uint256) {
        return _packets == 0 ? 0 : _packets - 1;
    }

    function rescueFunds(
        address token,
        address userAddress,
        uint256 amount
    ) external onlyOwner {
        require(userAddress != address(0));

        if (token == address(0)) {
            (bool success, ) = userAddress.call{value: address(this).balance}(
                ""
            );
            require(success);
        } else {
            // do we need safe transfer?
            IERC20(token).transfer(userAddress, amount);
        }
    }
}
