// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/examples/Messenger.sol";
import "./Setup.t.sol";

contract PingPongTest is Setup {
    bytes32 private constant _PING = keccak256("PING");
    bytes32 private constant _PONG = keccak256("PONG");

    bytes private constant _PROOF = abi.encode(0);
    bytes private _payloadPing;
    bytes private _payloadPong;
    bool private isFast = true;

    uint256 msgGasLimit = 130000;

    Messenger srcMessenger__;
    Messenger dstMessenger__;

    function setUp() external {
        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        // kept fees 0 to avoid revert at inbound<>outbound
        _dualChainSetup(attesters, 0);
        _deployPlugContracts();
        _configPlugContracts();

        _payloadPing = abi.encode(_a.chainSlug, _PING);
        _payloadPong = abi.encode(_b.chainSlug, _PONG);
    }

    function _verifyAToB(uint256 msgId_) internal {
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, accum, _b.chainSlug);

        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_b, sig, packetId, root);

        vm.warp(block.timestamp + _slowAccumWaitTime);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstMessenger__),
            packetId,
            msgId_,
            msgGasLimit,
            _payloadPing,
            _PROOF
        );

        assertEq(dstMessenger__.message(), _PING);
    }

    function _verifyBToA(uint256 msgId_) internal {
        address accum = isFast
            ? address(_b.fastAccum__)
            : address(_b.slowAccum__);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, accum, _a.chainSlug);

        _sealOnSrc(_b, accum, sig);
        _submitRootOnDst(_a, sig, packetId, root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _b,
            _a,
            address(srcMessenger__),
            packetId,
            msgId_,
            msgGasLimit,
            _payloadPong,
            _PROOF
        );

        assertEq(srcMessenger__.message(), _PONG);
    }

    function _reset() internal {
        dstMessenger__.sendLocalMessage(bytes32(0));
        srcMessenger__.sendLocalMessage(bytes32(0));
    }

    function testPingPong() external {
        hoax(_raju);
        srcMessenger__.sendRemoteMessage(_b.chainSlug, _PING);

        uint256 iterations = 5;
        for (uint256 index = 0; index < iterations; index++) {
            uint256 msgIdAToB = _packMessageId(_a.chainSlug, index);
            uint256 msgIdBToA = _packMessageId(_b.chainSlug, index);

            _verifyAToB(msgIdAToB);
            _verifyBToA(msgIdBToA);
            _reset();
        }
    }

    function _deployPlugContracts() private {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcMessenger__ = new Messenger(
            address(_a.socket__),
            _a.chainSlug,
            msgGasLimit
        );
        dstMessenger__ = new Messenger(
            address(_b.socket__),
            _b.chainSlug,
            msgGasLimit
        );

        vm.stopPrank();
    }

    function _configPlugContracts() private {
        string memory integrationType = isFast
            ? fastIntegrationType
            : slowIntegrationType;
        hoax(_plugOwner);
        srcMessenger__.setSocketConfig(
            _b.chainSlug,
            address(dstMessenger__),
            integrationType
        );

        hoax(_plugOwner);
        dstMessenger__.setSocketConfig(
            _a.chainSlug,
            address(srcMessenger__),
            integrationType
        );
    }
}
