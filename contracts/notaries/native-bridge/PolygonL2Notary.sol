// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";
import "fx-portal/tunnel/FxBaseChildTunnel.sol";

contract PolygonL2Notary is NativeBridgeNotary, FxBaseChildTunnel {
    event FxChildUpdate(address oldFxChild, address newFxChild);
    event FxRootTunnel(address fxRootTunnel, address fxRootTunnel_);
    modifier onlyRemoteAccumulator() override {
        _;
    }

    constructor(
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteNotary_,
        address fxChild_
    )
        NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteNotary_)
        FxBaseChildTunnel(fxChild_)
    {}

    /**
     * @param packetId - packet id
     * @param root - root hash
     */
    function _sendMessage(
        uint256[] calldata,
        uint256 packetId,
        bytes32 root
    ) internal override {
        bytes memory data = abi.encode(packetId, root, bytes(""));
        bytes memory fxData = abi.encode(address(this), remoteNotary, data);
        _sendMessageToRoot(fxData);
    }

    function _processMessageFromRoot(
        uint256,
        address rootMessageSender,
        bytes calldata data
    ) internal override {
        if (rootMessageSender != remoteNotary) revert InvalidAttester();
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

    function updateFxRootTunnel(address fxRootTunnel_) external onlyOwner {
        emit FxRootTunnel(fxRootTunnel, fxRootTunnel_);
        fxRootTunnel = fxRootTunnel_;
    }
}
