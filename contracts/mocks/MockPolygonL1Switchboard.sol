// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../switchboard/native/PolygonL1Switchboard.sol";

contract MockPolygonL1Switchboard is PolygonL1Switchboard {
    constructor(
        uint32 chainSlug_,
        address checkpointManager_,
        address fxRoot_,
        address owner_,
        address socket_,
        ISignatureVerifier signatureVerifier_
    )
        PolygonL1Switchboard(
            chainSlug_,
            checkpointManager_,
            fxRoot_,
            owner_,
            socket_,
            signatureVerifier_
        )
    {}

    function receivePacket(bytes memory data_) external {
        _processMessageFromChild(data_);
    }
}
