// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/optimism/ICrossDomainMessenger.sol";
import "./NativeSwitchboardBase.sol";

contract OptimismSwitchboard is NativeSwitchboardBase {
    uint256 public receiveGasLimit;
    uint256 public confirmGasLimit;

    ICrossDomainMessenger public immutable crossDomainMessenger__;

    event UpdatedReceiveGasLimit(uint256 receiveGasLimit);
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
        uint256 chainSlug_,
        uint256 receiveGasLimit_,
        uint256 confirmGasLimit_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        address owner_,
        IGasPriceOracle gasPriceOracle_,
        address crossDomainMessenger_
    )
        AccessControlExtended(owner_)
        NativeSwitchboardBase(
            chainSlug_,
            initiateGasLimit_,
            executionOverhead_,
            gasPriceOracle_
        )
    {
        receiveGasLimit = receiveGasLimit_;
        confirmGasLimit = confirmGasLimit_;
        crossDomainMessenger__ = ICrossDomainMessenger(crossDomainMessenger_);
    }

    function initiateNativeConfirmation(bytes32 packetId_) external {
        bytes memory data = _encodeRemoteCall(packetId_);

        crossDomainMessenger__.sendMessage(
            remoteNativeSwitchboard,
            data,
            uint32(receiveGasLimit)
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
        uint256 nonce_,
        uint256 confirmGasLimit_,
        bytes memory signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "L1_RECEIVE_GAS_LIMIT_UPDATE",
                    chainSlug,
                    nonce_,
                    confirmGasLimit_
                )
            ),
            signature_
        );

        if (!_hasRole(GAS_LIMIT_UPDATER_ROLE, gasLimitUpdater))
            revert NoPermit(GAS_LIMIT_UPDATER_ROLE);
        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        confirmGasLimit = confirmGasLimit_;
        emit UpdatedConfirmGasLimit(confirmGasLimit_);
    }

    function updateReceiveGasLimit(
        uint256 receiveGasLimit_
    ) external onlyRole(GOVERNANCE_ROLE) {
        receiveGasLimit = receiveGasLimit_;
        emit UpdatedReceiveGasLimit(receiveGasLimit_);
    }
}
