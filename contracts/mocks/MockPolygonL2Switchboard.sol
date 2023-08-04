// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../switchboard/native/PolygonL2Switchboard.sol";

contract MockPolygonL2Switchboard is PolygonL2Switchboard {
    constructor(
        uint32 chainSlug_,
        address fxChild_,
        address owner_,
        address socket_,
        ISignatureVerifier signatureVerifier_
    )
        PolygonL2Switchboard(
            chainSlug_,
            fxChild_,
            owner_,
            socket_,
            signatureVerifier_
        )
    {}

    function receivePacket(
        uint256 id,
        address rootMessageSender_,
        bytes memory data_
    ) external {
        _processMessageFromRoot(id, rootMessageSender_, data_);
    }
}
