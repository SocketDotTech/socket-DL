// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";
import "fx-portal/tunnel/FxBaseChildTunnel.sol";

contract PolygonChildReceiver is NativeBridgeNotary, FxBaseChildTunnel {
    event FxChildUpdate(address oldFxChild, address newFxChild);

    modifier onlyRemoteAccumulator() override {
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_,
        address fxChild_
    )
        NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteTarget_)
        FxBaseChildTunnel(fxChild_)
    {}

    function _processMessageFromRoot(
        uint256,
        address rootMessageSender,
        bytes calldata data
    ) internal override {
        if (rootMessageSender != remoteTarget) revert InvalidAttester();
        (uint256 packetId, bytes32 root, ) = abi.decode(
            data,
            (uint256, bytes32, bytes)
        );
        _attest(packetId, root);
    }

    /**
     * @notice Update the address of the FxChild
     * @param fxChild_ The address of the new FxChild
     **/
    function updateFxChild(address fxChild_) external onlyOwner {
        emit FxChildUpdate(fxChild, fxChild_);
        fxChild = fxChild_;
    }
}
