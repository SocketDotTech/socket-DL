// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface ISwitchboard {
    function allowPacket(
        bytes32 root,
        uint256 packetId,
        uint256 srcChainSlug,
        uint256 proposeTime
    ) external view returns (bool);

    function payFees(
        uint256 msgGasLimit,
        uint256 msgValue,
        uint256 dstChainSlug
    ) external payable;

    function getMinFees(
        uint256 msgGasLimit,
        uint256 msgValue,
        uint256 dstChainSlug
    ) external view returns (uint256);

    function getExecutionFees(
        uint256 msgGasLimit,
        uint256 msgValue,
        uint256 dstChainSlug
    ) external view returns (uint256);
}
