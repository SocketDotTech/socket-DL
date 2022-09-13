// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../src/examples/Messenger.sol";
import "./Setup.t.sol";

contract PingPongTest is Setup {
    bytes32 private constant _PING = keccak256("PING");
    bytes32 private constant _PONG = keccak256("PONG");

    bytes private constant _PROOF = abi.encode(0);
    bytes private _payloadPing;
    bytes private _payloadPong;

    uint256 msgGasLimit = 115000;

    Messenger srcMessenger__;
    Messenger destMessenger__;

    function setUp() external {
        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        _dualChainSetup(attesters);
        _deployPlugContracts();
        _configPlugContracts();

        _payloadPing = abi.encode(_a.chainId, _PING);
        _payloadPong = abi.encode(_b.chainId, _PONG);
    }

    function _verifyAToB(uint256 msgId_) internal {
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a);

        _verifyAndSealOnSrc(_a, _b, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        _executePayloadOnDst(
            _a,
            _b,
            address(destMessenger__),
            packetId,
            msgId_,
            msgGasLimit,
            _payloadPing,
            _PROOF
        );

        assertEq(destMessenger__.message(), _PING);
    }

    function _verifyBToA(uint256 msgId_) internal {
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b);

        _verifyAndSealOnSrc(_b, _a, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root);
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
        destMessenger__.sendLocalMessage(bytes32(0));
        srcMessenger__.sendLocalMessage(bytes32(0));
    }

    function testPingPong() external {
        hoax(_raju);
        srcMessenger__.sendRemoteMessage(_b.chainId, _PING);

        uint256 iterations = 5;
        for (uint256 index = 0; index < iterations; index++) {
            uint256 msgIdAToB = (uint64(_b.chainId) << 32) | index;
            uint256 msgIdBToA = (uint64(_a.chainId) << 32) | index;

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
            _a.chainId,
            msgGasLimit
        );
        destMessenger__ = new Messenger(
            address(_b.socket__),
            _b.chainId,
            msgGasLimit
        );

        vm.stopPrank();
    }

    function _configPlugContracts() private {
        hoax(_plugOwner);
        srcMessenger__.setSocketConfig(
            _b.chainId,
            address(destMessenger__),
            address(_a.accum__),
            address(_a.deaccum__),
            address(_a.verifier__)
        );

        hoax(_plugOwner);
        destMessenger__.setSocketConfig(
            _a.chainId,
            address(srcMessenger__),
            address(_b.accum__),
            address(_b.deaccum__),
            address(_b.verifier__)
        );
    }
}
