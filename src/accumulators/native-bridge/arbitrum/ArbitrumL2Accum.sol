// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../NativeBridgeAccum.sol";
import "../../../interfaces/INotary.sol";
import "../../../interfaces/native-bridge/IArbSys.sol";

contract ArbitrumL2Accum is NativeBridgeAccum {
    IArbSys constant arbsys = IArbSys(address(100));
    event L2ToL1TxCreated(uint256 indexed withdrawalId);

    constructor(
        address socket_,
        address notary_,
        uint32 remoteChainSlug_,
        uint32 chainSlug_
    ) NativeBridgeAccum(socket_, notary_, remoteChainSlug_, chainSlug_) {}

    function sendL2Message(uint256[] calldata, bytes memory data)
        internal
        override
    {
        uint256 withdrawalId = arbsys.sendTxToL1(remoteNotary, data);
        emit L2ToL1TxCreated(withdrawalId);
    }
}
