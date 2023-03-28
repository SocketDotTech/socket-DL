// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "fx-portal/tunnel/FxBaseChildTunnel.sol";
import "./NativeSwitchboardBase.sol";

contract PolygonL2Switchboard is NativeSwitchboardBase, FxBaseChildTunnel {
    uint256 public l1ReceiveGasLimit;

    event FxChildUpdate(address oldFxChild, address newFxChild);
    event FxRootTunnelSet(address fxRootTunnel, address newFxRootTunnel);
    event UpdatedL1ReceiveGasLimit(uint256 l1ReceiveGasLimit);

    modifier onlyRemoteSwitchboard() override {
        require(true, "ONLY_FX_CHILD");

        _;
    }

    constructor(
        uint256 l1ReceiveGasLimit_,
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
        address fxChild_,
        address owner_,
        IGasPriceOracle gasPriceOracle_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            initialConfirmationGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
        FxBaseChildTunnel(fxChild_)
    {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
    }

    /**
     * @param packetId_ - packet id
     */
    function initateNativeConfirmation(bytes32 packetId_) external payable {
        bytes memory data = _encodeRemoteCall(packetId_);

        _sendMessageToRoot(data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    /**
     * validate sender verifies if `rootMessageSender` is the root contract (notary) on L1.
     */
    function _processMessageFromRoot(
        uint256,
        address rootMessageSender_,
        bytes memory data_
    ) internal override validateSender(rootMessageSender_) {
        (bytes32 packetId, bytes32 root) = abi.decode(
            data_,
            (bytes32, bytes32)
        );
        packetIdToRoot[packetId] = root;
        emit RootReceived(packetId, root);
    }

    function _getMinSwitchboardFees(
        uint256,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        return
            initiateGasLimit *
            sourceGasPrice_ +
            l1ReceiveGasLimit *
            dstRelativeGasPrice_;
    }

    function updateL1ReceiveGasLimit(
        uint256 l1ReceiveGasLimit_
    ) external onlyRole(GAS_LIMIT_UPDATER_ROLE) {
        l1ReceiveGasLimit = l1ReceiveGasLimit_;
        emit UpdatedL1ReceiveGasLimit(l1ReceiveGasLimit_);
    }

    /**
     * @notice Update the address of the FxChild
     * @param fxChild_ The address of the new FxChild
     **/
    function updateFxChild(
        address fxChild_
    ) external onlyRole(GOVERNANCE_ROLE) {
        emit FxChildUpdate(fxChild, fxChild_);
        fxChild = fxChild_;
    }

    function setFxRootTunnel(
        address fxRootTunnel_
    ) external override onlyRole(GOVERNANCE_ROLE) {
        emit FxRootTunnelSet(fxRootTunnel, fxRootTunnel_);
        fxRootTunnel = fxRootTunnel_;
    }
}
