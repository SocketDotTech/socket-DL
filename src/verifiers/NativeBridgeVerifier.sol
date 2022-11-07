// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IVerifier.sol";
import "../interfaces/INotary.sol";

import "../utils/Ownable.sol";

contract NativeBridge is IVerifier, Ownable {
    INotary public notary;
    event NotarySet(address notary_);

    constructor(address owner_, address notary_) Ownable(owner_) {
        notary = INotary(notary_);
    }

    /**
     * @notice updates notary
     * @param notary_ address of Notary
     */
    function setNotary(address notary_) external onlyOwner {
        notary = INotary(notary_);
        emit NotarySet(notary_);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packet id
     */
    function verifyPacket(uint256 packetId_, bytes32)
        external
        view
        override
        returns (bool, bytes32)
    {
        (INotary.PacketStatus status, , , bytes32 root) = notary
            .getPacketDetails(packetId_);

        if (status == INotary.PacketStatus.PROPOSED) return (true, root);
        return (false, root);
    }
}
