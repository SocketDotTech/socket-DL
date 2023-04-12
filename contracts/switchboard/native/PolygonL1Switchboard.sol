// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseRootTunnel.sol";
import "./NativeSwitchboardBase.sol";

contract PolygonL1Switchboard is NativeSwitchboardBase, FxBaseRootTunnel {
    event FxChildTunnelSet(address fxRootTunnel, address newFxRootTunnel);

    modifier onlyRemoteSwitchboard() override {
        require(true, "ONLY_FX_CHILD");

        _;
    }

    constructor(
        uint256 chainSlug_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address checkpointManager_,
        address fxRoot_,
        address owner_,
        address socket_,
        IGasPriceOracle gasPriceOracle_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            socket_,
            chainSlug_,
            initiateGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
        FxBaseRootTunnel(checkpointManager_, fxRoot_)
    {}

    /**
     * @param packetId_ - packet id
     */
    function initiateNativeConfirmation(bytes32 packetId_) external payable {
        bytes memory data = _encodeRemoteCall(packetId_);
        _sendMessageToChild(data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    function _processMessageFromChild(bytes memory message_) internal override {
        (bytes32 packetId, bytes32 root) = abi.decode(
            message_,
            (bytes32, bytes32)
        );
        packetIdToRoot[packetId] = root;
        emit RootReceived(packetId, root);
    }

    function _getMinSwitchboardFees(
        uint256,
        uint256,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return initiateGasLimit * sourceGasPrice_;
    }

    // set fxChildTunnel if not set already
    function setFxChildTunnel(
        address fxChildTunnel_
    ) public override onlyRole(GOVERNANCE_ROLE) {
        emit FxChildTunnelSet(fxChildTunnel, fxChildTunnel_);
        fxChildTunnel = fxChildTunnel_;
    }
}
