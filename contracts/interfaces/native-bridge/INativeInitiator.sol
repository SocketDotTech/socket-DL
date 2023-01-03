// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface INativeInitiator {
    function initateNativeConfirmation(uint256 packetId) external payable;
}
