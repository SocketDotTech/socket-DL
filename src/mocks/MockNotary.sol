// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/INotary.sol";

contract MockNotary {
    function getPacketDetails(
        address,
        uint256,
        uint256
    )
        external
        pure
        returns (
            bool isConfirmed,
            uint256 packetArrivedAt,
            bytes32 root
        )
    {
        return (true, 0, bytes32(0));
    }
}
