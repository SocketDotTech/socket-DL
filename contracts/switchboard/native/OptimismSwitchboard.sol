// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/optimism/ICrossDomainMessenger.sol";
import "./NativeSwitchboardBase.sol";
import {GOVERNANCE_ROLE, GAS_LIMIT_UPDATER_ROLE} from "../../utils/AccessRoles.sol";

contract OptimismSwitchboard is NativeSwitchboardBase {
    uint256 public receivePacketGasLimit;
    uint256 public l1ReceiveGasLimit;

    ICrossDomainMessenger public crossDomainMessenger__;

    event UpdatedReceivePacketGasLimit(uint256 receivePacketGasLimit);
    event UpdatedL1ReceiveGasLimit(uint256 l1ReceiveGasLimit);

    modifier onlyRemoteSwitchboard() override {
        if (
            msg.sender != address(crossDomainMessenger__) &&
            crossDomainMessenger__.xDomainMessageSender() !=
            remoteNativeSwitchboard
        ) revert InvalidSender();
        _;
    }

    constructor(
        uint256 receivePacketGasLimit_,
        uint256 l1ReceiveGasLimit_,
        uint256 initialConfirmationGasLimit_,
        uint256 executionOverhead_,
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
        receivePacketGasLimit = receivePacketGasLimit_;
        l1ReceiveGasLimit = l1ReceiveGasLimit_;

        if ((block.chainid == 10 || block.chainid == 420)) {
            crossDomainMessenger__ = ICrossDomainMessenger(
                0x4200000000000000000000000000000000000007
            );
        } else {
            crossDomainMessenger__ = block.chainid == 1
                ? ICrossDomainMessenger(
                    0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1
                )
                : ICrossDomainMessenger(
                    0x5086d1eEF304eb5284A0f6720f79403b4e9bE294
                );
        }
    }

    function initateNativeConfirmation(bytes32 packetId_) external {
        bytes memory data = _encodeRemoteCall(packetId_);

        crossDomainMessenger__.sendMessage(
            remoteNativeSwitchboard,
            data,
            uint32(receivePacketGasLimit)
        );
        emit InitiatedNativeConfirmation(packetId_);
    }

    function _getMinSwitchboardFees(
        uint256,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
        // l1ReceiveGasLimit will be 0 when switchboard is deployed on L1
        return
            initateNativeConfirmationGasLimit *
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

    function updateReceivePacketGasLimit(
        uint256 receivePacketGasLimit_
    ) external onlyRole(GOVERNANCE_ROLE) {
        receivePacketGasLimit = receivePacketGasLimit_;
        emit UpdatedReceivePacketGasLimit(receivePacketGasLimit_);
    }
}
