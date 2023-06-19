// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

/**
 * @title ISwitchboard
 * @dev The interface for a switchboard contract that is responsible for verification of packets between
 * different blockchain networks.
 */
interface ISwitchboard {
    /**
     * @notice Registers itself in Socket for given `siblingChainSlug_`.
     * @dev This function is expected to be only called by admin as it handles the capacitor config for given chain
     * @param siblingChainSlug_ The slug of the sibling chain to register switchboard with.
     * @param maxPacketLength_ The maximum length of a packet allowed by the switchboard.
     * @param capacitorType_ The type of capacitor that the switchboard uses.
     * @param initialPacketCount_ The packet count at the time of registering switchboard. Packets with packet count below this won't be allowed
     */
    function registerSiblingSlug(
        uint32 siblingChainSlug_,
        uint256 maxPacketLength_,
        uint256 capacitorType_,
        uint256 initialPacketCount_
    ) external;

    /**
     * @notice Checks if a packet can be allowed to go through the switchboard.
     * @param root the packet root.
     * @param packetId The unique identifier for the packet.
     * @param proposalCount The unique identifier for a proposal for the packet.
     * @param srcChainSlug The unique identifier for the source chain of the packet.
     * @param proposeTime The time when the packet was proposed.
     * @return A boolean indicating whether the packet is allowed to go through the switchboard or not.
     */
    function allowPacket(
        bytes32 root,
        bytes32 packetId,
        uint256 proposalCount,
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
    ) external view returns (uint128 switchboardFee, uint128 verificationFee);

    function setFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint128 verificationFees_,
        uint128 switchboardFees_,
        bytes calldata signature_
    ) external;

    function withdrawFeesFromExecutionManager(
        uint32 siblingChainSlug_,
        uint128 amount_
    ) external;
}
