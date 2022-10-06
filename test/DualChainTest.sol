// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../src/examples/Counter.sol";

contract DualChainTest is Setup {
    Counter srcCounter__;
    Counter destCounter__;
    uint256 minFees = 10000;
    uint256 addAmount = 100;
    uint256 subAmount = 40;
    bool isFast = true;

    // the identifiers of the forks
    uint256 aFork;
    uint256 bFork;

    function setUp() public {
        _a.chainId = 80001;
        _b.chainId = 420;

        aFork = vm.createFork(vm.envString("CHAIN1_RPC_URL"));
        bFork = vm.createFork(vm.envString("CHAIN2_RPC_URL"));

        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        vm.selectFork(aFork);
        _a = _deployContractsOnSingleChain(_a.chainId, _b.chainId);
        _addAttesters(attesters, _a, _b.chainId);

        vm.selectFork(bFork);
        _b = _deployContractsOnSingleChain(_b.chainId, _a.chainId);
        _addAttesters(attesters, _b, _a.chainId);

        _deployPlugContracts();
        _configPlugContracts();
    }

    function testRemoteAddFromAtoB() external {
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        hoax(_raju);
        vm.selectFork(aFork);
        srcCounter__.remoteAddOperation(_b.chainId, amount, _msgGasLimit);

        // TODO: get nonce from event
        uint256 msgId = _packMessageId(
            address(srcCounter__),
            _a.chainId,
            _b.chainId,
            0
        );

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);

        vm.selectFork(bFork);
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

        vm.selectFork(aFork);
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
        vm.selectFork(bFork);
        destCounter__.remoteAddOperation(_a.chainId, amount, _msgGasLimit);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, accum, _a.chainId);

        uint256 msgId = _packMessageId(
            address(destCounter__),
            _b.chainId,
            _a.chainId,
            0
        );
        _sealOnSrc(_b, accum, sig);

        vm.selectFork(aFork);
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

        vm.selectFork(bFork);
        assertEq(destCounter__.counter(), 0);
    }

    function testRemoteAddAndSubtract() external {
        bytes memory addPayload = abi.encode(keccak256("OP_ADD"), addAmount);
        uint256 addMsgId = _packMessageId(
            address(srcCounter__),
            _a.chainId,
            _b.chainId,
            0
        );
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        bytes memory subPayload = abi.encode(keccak256("OP_SUB"), subAmount);
        uint256 subMsgId = _packMessageId(
            address(srcCounter__),
            _a.chainId,
            _b.chainId,
            1
        );

        bytes32 root;
        uint256 packetId;
        bytes memory sig;

        hoax(_raju);
        vm.selectFork(aFork);
        srcCounter__.remoteAddOperation(_b.chainId, addAmount, _msgGasLimit);

        (root, packetId, sig) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);

        vm.selectFork(bFork);
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
        vm.selectFork(aFork);
        srcCounter__.remoteSubOperation(_b.chainId, subAmount, _msgGasLimit);

        (root, packetId, sig) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);

        vm.selectFork(bFork);
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

        vm.selectFork(aFork);
        assertEq(srcCounter__.counter(), 0);
    }

    function testExecSameMessageTwice() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        uint256 msgId = _packMessageId(
            address(srcCounter__),
            _a.chainId,
            _b.chainId,
            0
        );
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        hoax(_raju);
        vm.selectFork(aFork);
        srcCounter__.remoteAddOperation(_b.chainId, amount, _msgGasLimit);
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);

        vm.selectFork(bFork);
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

        vm.selectFork(aFork);
        assertEq(srcCounter__.counter(), 0);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        vm.selectFork(aFork);
        srcCounter__ = new Counter(address(_a.socket__));

        vm.selectFork(bFork);
        destCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts() internal {
        string memory accumName = isFast ? fastAccumName : slowAccumName;

        hoax(_plugOwner);
        vm.selectFork(aFork);
        srcCounter__.setSocketConfig(
            _b.chainId,
            address(destCounter__),
            accumName
        );

        hoax(_plugOwner);
        vm.selectFork(bFork);
        destCounter__.setSocketConfig(
            _a.chainId,
            address(srcCounter__),
            accumName
        );
    }
}
