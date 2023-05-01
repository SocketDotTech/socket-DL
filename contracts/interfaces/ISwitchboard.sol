// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

/**
 * @title ISwitchboard
 * @dev The interface for a switchboard contract that is responsible for verification of packets between
 * different blockchain networks.
 */
interface ISwitchboard {
    /**
     * @notice Registers a capacitor to the switchboard.
     * @dev The capacitor is identified by its address and a unique `siblingChainSlug`.
     * @param siblingChainSlug_ The unique identifier for the sibling chain the capacitor is connected to.
     * @param capacitor_ The address of the capacitor contract.
     * @param maxPacketSize_ The maximum size of the packets that can be sent through this capacitor.
     */
    function registerCapacitor(
        uint256 siblingChainSlug_,
        address capacitor_,
        uint256 maxPacketSize_
    ) external;

    /**
     * @notice Checks if a packet can be allowed to go through the switchboard.
     * @param root the packet root.
     * @param packetId The unique identifier for the packet.
     * @param srcChainSlug The unique identifier for the source chain of the packet.
     * @param proposeTime The time when the packet was proposed.
     * @return A boolean indicating whether the packet is allowed to go through the switchboard or not.
     */
    function allowPacket(
        bytes32 root,
        bytes32 packetId,
        uint32 srcChainSlug,
        uint256 proposeTime
    ) external view returns (bool);

    /**
     * @notice Pays the fees required for the destination chain to process the packet.
     * @dev The fees are paid by the sender of the packet to the switchboard contract.
     * @param dstChainSlug The unique identifier for the destination chain of the packet.
     */
    function payFees(uint32 dstChainSlug) external payable;

    /**
     * @notice Retrieves the minimum fees required for the destination chain to process the packet.
     * @param dstChainSlug the unique identifier for the destination chain of the packet.
     * @return switchboardFee the switchboard fee required for the destination chain to process the packet.
     * @return verificationFee the verification fee required for the destination chain to process the packet.
     */
    function getMinFees(
        uint32 dstChainSlug
    ) external view returns (uint256 switchboardFee, uint256 verificationFee);
}
