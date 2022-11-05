// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./BaseAccum.sol";
import "../interfaces/INotary.sol";
import "../interfaces/native-bridge/IArbSys.sol";

contract ArbitrumL2Accum is BaseAccum {
    address public remoteNotary;
    IArbSys constant arbsys = IArbSys(address(100));

    event L2ToL1TxCreated(uint256 indexed withdrawalId);

    constructor(
        address socket_,
        address notary_,
        uint32 remoteChainSlug_
    ) BaseAccum(socket_, notary_, remoteChainSlug_) {}

    function setRemoteNotary(address notary_) external onlyOwner {
        remoteNotary = notary_;
    }

    function sealPacket(uint256[] calldata, bytes calldata signature_)
        external
        payable
        override
        onlyRole(NOTARY_ROLE)
        returns (
            bytes32,
            uint256,
            uint256
        )
    {
        if (_roots[_sealedPackets] == bytes32(0)) revert NoPendingPacket();
        bytes memory data = abi.encodeWithSelector(
            INotary.attest.selector,
            _sealedPackets,
            _roots[_sealedPackets],
            signature_
        );

        uint256 withdrawalId = arbsys.sendTxToL1(remoteNotary, data);

        emit L2ToL1TxCreated(withdrawalId);
        emit PacketComplete(_roots[_sealedPackets], _sealedPackets);
        return (_roots[_sealedPackets], _sealedPackets++, remoteChainSlug);
    }

    function addPackedMessage(bytes32 packedMessage)
        external
        override
        onlyRole(SOCKET_ROLE)
    {
        uint256 packetId = _packets;
        _roots[packetId] = packedMessage;
        _packets++;

        emit MessageAdded(packedMessage, packetId, packedMessage);
    }
}
