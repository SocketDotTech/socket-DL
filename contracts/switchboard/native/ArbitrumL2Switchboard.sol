// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "openzeppelin-contracts/contracts/vendor/arbitrum/IArbSys.sol";

import "../../libraries/AddressAliasHelper.sol";
import "./NativeSwitchboardBase.sol";

contract ArbitrumL2Switchboard is NativeSwitchboardBase {
    uint256 public confirmGasLimit;
    IArbSys public immutable arbsys__ = IArbSys(address(100));
    event UpdatedConfirmGasLimit(uint256 confirmGasLimit);

    modifier onlyRemoteSwitchboard() override {
        if (
            msg.sender !=
            AddressAliasHelper.applyL1ToL2Alias(remoteNativeSwitchboard)
        ) revert InvalidSender();
        _;
    }

    constructor(
        uint256 chainSlug_,
        uint256 confirmGasLimit_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
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
    {
        confirmGasLimit = confirmGasLimit_;
    }

    function initiateNativeConfirmation(bytes32 packetId_) external {
        bytes memory data = _encodeRemoteCall(packetId_);

        arbsys__.sendTxToL1(remoteNativeSwitchboard, data);
        emit InitiatedNativeConfirmation(packetId_);
    }

    function _getMinSwitchboardFees(
        uint256,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view override returns (uint256) {
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
}
