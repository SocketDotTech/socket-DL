// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/optimism/ICrossDomainMessenger.sol";
import "./NativeSwitchboardBase.sol";

contract OptimismSwitchboard is NativeSwitchboardBase {
    uint256 public receivePacketGasLimit;
    uint256 public confirmGasLimit;

    ICrossDomainMessenger public crossDomainMessenger__;

    event UpdatedReceivePacketGasLimit(uint256 receivePacketGasLimit);
    event UpdatedConfirmGasLimit(uint256 confirmGasLimit);

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
        uint256 confirmGasLimit_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address owner_,
        IGasPriceOracle gasPriceOracle_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            initiateGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
    {
        receivePacketGasLimit = receivePacketGasLimit_;
        confirmGasLimit = confirmGasLimit_;

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
        // confirmGasLimit will be 0 when switchboard is deployed on L1
        return
            initiateGasLimit *
            sourceGasPrice_ +
            confirmGasLimit *
            dstRelativeGasPrice_;
    }

    function updateConfirmGasLimit(
        uint256 confirmGasLimit_
    ) external onlyRole(GAS_LIMIT_UPDATER_ROLE) {
        confirmGasLimit = confirmGasLimit_;
        emit UpdatedConfirmGasLimit(confirmGasLimit_);
    }

    function updateReceivePacketGasLimit(
        uint256 receivePacketGasLimit_
    ) external onlyRole(GOVERNANCE_ROLE) {
        receivePacketGasLimit = receivePacketGasLimit_;
        emit UpdatedReceivePacketGasLimit(receivePacketGasLimit_);
    }
}
