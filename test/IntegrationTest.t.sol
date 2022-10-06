// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../src/examples/Counter.sol";

contract HappyTest is Setup {
    Counter srcCounter__;
    Counter destCounter__;
    uint256 minFees = 10000;
    uint256 addAmount = 100;
    uint256 subAmount = 40;

    bool isFast = true;

    function setUp() external {
        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        _dualChainSetup(attesters, minFees);
        _deployPlugContracts();
        _configPlugContracts(isFast);
    }

    function testRemoteAddFromAtoB() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            amount,
            _msgGasLimit
        );
        // TODO: get nonce from event

        uint256 msgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(destCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
    }

    function testRemoteAddFromBtoA() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address accum = isFast
            ? address(_b.fastAccum__)
            : address(_b.slowAccum__);

        hoax(_raju);
        destCounter__.remoteAddOperation{value: minFees}(
            _a.chainId,
            amount,
            _msgGasLimit
        );

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, accum, _a.chainId);

        uint256 msgId = (uint256(uint160(address(destCounter__))) << 96) |
            (_b.chainId << 80) |
            (_a.chainId << 64) |
            0;
        _sealOnSrc(_b, accum, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root, accum);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _b,
            _a,
            address(srcCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(srcCounter__.counter(), amount);
        assertEq(destCounter__.counter(), 0);
    }

    function testRemoteAddAndSubtract() external {
        bytes memory addPayload = abi.encode(keccak256("OP_ADD"), addAmount);
        uint256 addMsgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        bytes memory subPayload = abi.encode(keccak256("OP_SUB"), subAmount);
        uint256 subMsgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            1;
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        bytes32 root;
        uint256 packetId;
        bytes memory sig;

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            addAmount,
            _msgGasLimit
        );

        (root, packetId, sig) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            addMsgId,
            _msgGasLimit,
            accum,
            addPayload,
            abi.encode(0)
        );

        hoax(_raju);
        srcCounter__.remoteSubOperation{value: minFees}(
            _b.chainId,
            subAmount,
            _msgGasLimit
        );

        (root, packetId, sig) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            subMsgId,
            _msgGasLimit,
            accum,
            subPayload,
            abi.encode(0)
        );

        assertEq(destCounter__.counter(), addAmount - subAmount);
        assertEq(srcCounter__.counter(), 0);
    }

    function testExecSameMessageTwice() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        uint256 msgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            amount,
            _msgGasLimit
        );
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        vm.expectRevert(ISocket.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(destCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcCounter__ = new Counter(address(_a.socket__));
        destCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts(bool isFast_) internal {
        string memory accumName = isFast_ ? fastAccumName : slowAccumName;
        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainId,
            address(destCounter__),
            accumName
        );

        hoax(_plugOwner);
        destCounter__.setSocketConfig(
            _a.chainId,
            address(srcCounter__),
            accumName
        );
    }
}
