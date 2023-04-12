// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface ISwitchboard {
    function registerCapacitor(
        uint256 siblingChainSlug_,
        address capacitor_,
        uint256 maxPacketSize_
    ) external;

    function allowPacket(
        bytes32 root,
        bytes32 packetId,
        uint32 srcChainSlug,
        uint256 proposeTime
    ) external view returns (bool);

    function payFees(uint32 dstChainSlug) external payable;

    function getMinFees(
        uint32 dstChainSlug
    ) external view returns (uint256 switchboardFee, uint256 verificationFee);
}
