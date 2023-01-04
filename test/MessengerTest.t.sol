// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/examples/Messenger.sol";
import "./Setup.t.sol";

contract PingPongTest is Setup {
    bytes32 private constant _PING = keccak256("PING");
    bytes32 private constant _PONG = keccak256("PONG");
    uint256 private constant ITERATIONS = 5;

    bytes private constant _PROOF = abi.encode(0);
    bytes private _payloadPing;
    bytes private _payloadPong;
    bool private isFast = true;

    uint256 msgGasLimit = 140000;

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
        address capacitor = isFast
            ? address(_a.fastCapacitor__)
            : address(_a.slowCapacitor__);
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, capacitor, _b.chainSlug);

        _sealOnSrc(_a, capacitor, sig);
        _submitRootOnDst(_b, sig, packetId, root);

        vm.warp(block.timestamp + _slowCapacitorWaitTime);
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
        address capacitor = isFast
            ? address(_b.fastCapacitor__)
            : address(_b.slowCapacitor__);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, capacitor, _a.chainSlug);

        _sealOnSrc(_b, capacitor, sig);
        _submitRootOnDst(_a, sig, packetId, root);
        vm.warp(block.timestamp + _slowCapacitorWaitTime);

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

    function testAdminRemoveGas() external {
        uint256 initialContractBal = address(srcMessenger__).balance;
        uint256 initialRajuBal = _raju.balance;
        assertGt(initialContractBal, 0, "Messenger has no balance");

        hoax(_plugOwner);
        srcMessenger__.removeGas(payable(_raju));

        assertEq(
            address(srcMessenger__).balance,
            0,
            "Messenger has balance after remove"
        );
        assertEq(
            _raju.balance,
            initialRajuBal + initialContractBal,
            "Raju did not receive full gas"
        );
    }

    function testRajuRemoveGas() external {
        hoax(_raju);
        vm.expectRevert(Ownable.OnlyOwner.selector);
        srcMessenger__.removeGas(payable(_raju));
    }

    function testPingPong() external {
        hoax(_raju);
        srcMessenger__.sendRemoteMessage(_b.chainSlug, _PING);

        for (uint256 index = 0; index < ITERATIONS; index++) {
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
        uint256 socketFee = srcMessenger__.SOCKET_FEE();
        vm.deal(_plugOwner, socketFee * ITERATIONS * 4);
        vm.startPrank(_plugOwner);
        string memory integrationType = isFast
            ? fastIntegrationType
            : slowIntegrationType;
        srcMessenger__.setSocketConfig(
            _b.chainSlug,
            address(dstMessenger__),
            address(0) // integrationType // TODO: change to switchboard
        );
        payable(srcMessenger__).transfer(socketFee * ITERATIONS * 2);

        dstMessenger__.setSocketConfig(
            _a.chainSlug,
            address(srcMessenger__),
            address(0) // integrationType // TODO: change to switchboard
        );
        payable(dstMessenger__).transfer(socketFee * ITERATIONS * 2);

        vm.stopPrank();
    }
}
