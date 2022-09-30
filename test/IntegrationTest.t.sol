// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../src/examples/Counter.sol";

contract HappyTest is Setup {
    Counter srcCounter__;
    Counter destCounter__;

    function setUp() external {
        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        _dualChainSetup(attesters);
        _deployPlugContracts();
        _configPlugContracts();
    }

    function testRemoteAddFromAtoB() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, amount, _msgGasLimit);
        // TODO: get nonce from event

        uint256 msgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            msgId,
            _msgGasLimit,
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

        hoax(_raju);
        destCounter__.remoteAddOperation(_a.chainId, amount, _msgGasLimit);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b);

        uint256 msgId = (uint256(uint160(address(destCounter__))) << 96) |
            (_b.chainId << 80) |
            (_a.chainId << 64) |
            0;
        _sealOnSrc(_b, _a, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _b,
            _a,
            address(srcCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );

        assertEq(srcCounter__.counter(), amount);
        assertEq(destCounter__.counter(), 0);
    }

    function testRemoteAddAndSubtract() external {
        uint256 addAmount = 100;
        bytes memory addPayload = abi.encode(keccak256("OP_ADD"), addAmount);
        uint256 addMsgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        uint256 subAmount = 40;
        bytes memory subPayload = abi.encode(keccak256("OP_SUB"), subAmount);
        uint256 subMsgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            1;

        bytes32 root;
        uint256 packetId;
        bytes memory sig;

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, addAmount, _msgGasLimit);

        (root, packetId, sig) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            addMsgId,
            _msgGasLimit,
            addPayload,
            abi.encode(0)
        );

        hoax(_raju);
        srcCounter__.remoteSubOperation(_b.chainId, subAmount, _msgGasLimit);

        (root, packetId, sig) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            subMsgId,
            _msgGasLimit,
            subPayload,
            abi.encode(0)
        );

        assertEq(destCounter__.counter(), addAmount - subAmount);
        assertEq(srcCounter__.counter(), 0);
    }

    function testMessagesOutOfOrderForSequentialConfig() external {
        _configPlugContracts();

        MessageContext memory m1;
        m1.amount = 100;
        m1.payload = abi.encode(keccak256("OP_ADD"), m1.amount);
        m1.proof = abi.encode(0);
        m1.msgId =
            (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, m1.amount, _msgGasLimit);

        (m1.root, m1.packetId, m1.sig) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, m1.sig);
        _submitRootOnDst(_a, _b, m1.sig, m1.packetId, m1.root);

        MessageContext memory m2;
        m2.amount = 40;
        m2.payload = abi.encode(keccak256("OP_ADD"), m2.amount);
        m2.proof = abi.encode(0);
        m2.msgId =
            (uint256(uint160(address(destCounter__))) << 96) |
            (_b.chainId << 80) |
            (_a.chainId << 64) |
            1;

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, m2.amount, _msgGasLimit);

        (m2.root, m2.packetId, m2.sig) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, m2.sig);
        _submitRootOnDst(_a, _b, m2.sig, m2.packetId, m2.root);
    }

    function testMessagesOutOfOrderForNonSequentialConfig() external {
        _configPlugContracts();

        MessageContext memory m1;
        m1.amount = 100;
        m1.payload = abi.encode(keccak256("OP_ADD"), m1.amount);
        m1.proof = abi.encode(0);
        m1.msgId =
            (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, m1.amount, _msgGasLimit);

        (m1.root, m1.packetId, m1.sig) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, m1.sig);
        _submitRootOnDst(_a, _b, m1.sig, m1.packetId, m1.root);

        MessageContext memory m2;
        m2.amount = 40;
        m2.payload = abi.encode(keccak256("OP_ADD"), m2.amount);
        m2.proof = abi.encode(0);
        m2.msgId =
            (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            1;

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, m2.amount, _msgGasLimit);

        (m2.root, m2.packetId, m2.sig) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, m2.sig);
        _submitRootOnDst(_a, _b, m2.sig, m2.packetId, m2.root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            m2.packetId,
            m2.msgId,
            _msgGasLimit,
            m2.payload,
            m2.proof
        );
        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            m1.packetId,
            m1.msgId,
            _msgGasLimit,
            m1.payload,
            m1.proof
        );

        assertEq(destCounter__.counter(), m1.amount + m2.amount);
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

        hoax(_raju);
        srcCounter__.remoteAddOperation(_b.chainId, amount, _msgGasLimit);
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a);
        _sealOnSrc(_a, _b, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root);
        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(destCounter__),
            packetId,
            msgId,
            _msgGasLimit,
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

    function _configPlugContracts() internal {
        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainId,
            address(destCounter__),
            bytes32(0)
        );

        hoax(_plugOwner);
        destCounter__.setSocketConfig(
            _a.chainId,
            address(srcCounter__),
            bytes32(0)
        );
    }
}
