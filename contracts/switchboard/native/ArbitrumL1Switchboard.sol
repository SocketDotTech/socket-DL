// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/arbitrum/IBridge.sol";
import "openzeppelin-contracts/contracts/vendor/arbitrum/IInbox.sol";
import "openzeppelin-contracts/contracts/vendor/arbitrum/IOutbox.sol";

import "./NativeSwitchboardBase.sol";

contract ArbitrumL1Switchboard is NativeSwitchboardBase {
    address public remoteRefundAddress;
    address public callValueRefundAddress;
    uint256 public arbitrumNativeFee;

    IInbox public inbox__;

    event UpdatedInboxAddress(address inbox);
    event UpdatedRefundAddresses(
        address remoteRefundAddress,
        address callValueRefundAddress
    );
    event UpdatedArbitrumNativeFee(uint256 arbitrumNativeFee);

    modifier onlyRemoteSwitchboard() override {
        IBridge bridge__ = IBridge(inbox__.bridge());
        if (msg.sender != address(bridge__)) revert InvalidSender();

        IOutbox outbox__ = IOutbox(bridge__.activeOutbox());
        address l2Sender = outbox__.l2ToL1Sender();
        if (l2Sender != remoteNativeSwitchboard) revert InvalidSender();

        _;
    }

    constructor(
        uint256 arbitrumNativeFee_,
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
        address inbox_,
        address owner_,
        IGasPriceOracle gasPriceOracle_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            initialConfirmationGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
    {
        inbox__ = IInbox(inbox_);
        arbitrumNativeFee = arbitrumNativeFee_;

        remoteRefundAddress = msg.sender;
        callValueRefundAddress = msg.sender;
    }

    function initateNativeConfirmation(
        bytes32 packetId_,
        uint256 maxSubmissionCost_,
        uint256 maxGas_,
        uint256 gasPriceBid_
    ) external payable {
        bytes memory data = _encodeRemoteCall(packetId_);

        // to avoid stack too deep
        address callValueRefund = callValueRefundAddress;
        address remoteRefund = remoteRefundAddress;

        inbox__.createRetryableTicket{value: msg.value}(
            remoteNativeSwitchboard,
            0, // no value needed for receivePacket
            maxSubmissionCost_,
            remoteRefund,
            callValueRefund,
            maxGas_,
            gasPriceBid_,
            data
        );

        emit InitiatedNativeConfirmation(packetId_);
    }

    function _getMinSwitchboardFees(
        uint256,
        uint256,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        // TODO: check if dynamic fees can be divided into more constants
        // arbitrum: check src contract
        return initiateGasLimit * sourceGasPrice_ + arbitrumNativeFee;
    }

    function updateRefundAddresses(
        address remoteRefundAddress_,
        address callValueRefundAddress_
    ) external onlyRole(GOVERNANCE_ROLE) {
        remoteRefundAddress = remoteRefundAddress_;
        callValueRefundAddress = callValueRefundAddress_;

        emit UpdatedRefundAddresses(
            remoteRefundAddress_,
            callValueRefundAddress_
        );
    }

    function updateArbitrumNativeFee(
        uint256 arbitrumNativeFee_
    ) external onlyRole(GAS_LIMIT_UPDATER_ROLE) {
        arbitrumNativeFee = arbitrumNativeFee_;
        emit UpdatedArbitrumNativeFee(arbitrumNativeFee_);
    }

    function updateInboxAddresses(
        address inbox_
    ) external onlyRole(GOVERNANCE_ROLE) {
        inbox__ = IInbox(inbox_);
        emit UpdatedInboxAddress(inbox_);
    }
}
