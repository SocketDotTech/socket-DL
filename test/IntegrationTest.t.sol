// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../src/examples/Counter.sol";

contract HappyTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;
    uint256 minFees = 10000;
    uint256 addAmount = 100;
    uint256 subAmount = 40;

    bool isFast = true;

    event ExecutionSuccess(uint256 msgId);
    event ExecutionFailed(uint256 msgId, string result);
    event ExecutionFailedBytes(uint256 msgId, bytes result);

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
        address attester = vm.addr(_attesterPrivateKey);

        // not an attester
        {
            hoax(_socketOwner);
            _a.notary__.revokeAttesterRole(_b.chainId, attester);
            vm.expectRevert(INotary.InvalidAttester.selector);
            _sealOnSrc(_a, accum, sig);

            hoax(_socketOwner);
            _a.notary__.grantAttesterRole(_b.chainId, attester);
        }

        _sealOnSrc(_a, accum, sig);

        // revert execution if packet not proposed
        assertEq(
            uint256(_b.notary__.getPacketStatus(accum, _a.chainId, packetId)),
            0
        );

        vm.expectRevert(ISocket.VerificationFailed.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        _submitRootOnDst(_a, _b, sig, packetId, root, accum);

        vm.expectRevert(INotary.AlreadyProposed.selector);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);

        // revert execution if packet paused
        {
            hoax(_socketOwner);
            _b.notary__.pausePacketOnRemote(accum, _a.chainId, packetId, root);

            assertEq(
                uint256(
                    _b.notary__.getPacketStatus(accum, _a.chainId, packetId)
                ),
                2
            );

            vm.expectRevert(ISocket.VerificationFailed.selector);
            _executePayloadOnDst(
                _a,
                _b,
                address(dstCounter__),
                packetId,
                msgId,
                _msgGasLimit,
                accum,
                payload,
                proof
            );

            hoax(_socketOwner);
            _b.notary__.acceptPausedPacket(accum, _a.chainId, packetId);
        }

        // without executor role
        {
            hoax(_socketOwner);
            _b.socket__.revokeExecutorRole(_raju);

            vm.expectRevert(ISocket.ExecutorNotFound.selector);
            _executePayloadOnDst(
                _a,
                _b,
                address(dstCounter__),
                packetId,
                msgId,
                _msgGasLimit,
                accum,
                payload,
                proof
            );

            hoax(_socketOwner);
            _b.socket__.grantExecutorRole(_raju);
        }

        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(msgId);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);

        vm.expectRevert(ISocket.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );
    }

    function testRemoteAddFromBtoA() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address accum = isFast
            ? address(_b.fastAccum__)
            : address(_b.slowAccum__);

        hoax(_raju);
        dstCounter__.remoteAddOperation{value: minFees}(
            _a.chainId,
            amount,
            _msgGasLimit
        );

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, accum, _a.chainId);

        uint256 msgId = (uint256(uint160(address(dstCounter__))) << 96) |
            (_b.chainId << 80) |
            (_a.chainId << 64) |
            0;
        _sealOnSrc(_b, accum, sig);
        _submitRootOnDst(_b, _a, sig, packetId, root, accum);

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
        assertEq(dstCounter__.counter(), 0);
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
        vm.expectRevert(Vault.NotEnoughFees.selector);
        srcCounter__.remoteAddOperation(_b.chainId, addAmount, _msgGasLimit);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            addAmount,
            _msgGasLimit
        );

        (root, packetId, sig) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
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

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            subMsgId,
            _msgGasLimit,
            accum,
            subPayload,
            abi.encode(0)
        );

        assertEq(dstCounter__.counter(), addAmount - subAmount);
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

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
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
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
    }

    function testExecuteWithLowGasLimit() external {
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

        // providing a lower gas limit
        uint256 msgGasLimit = 1000;
        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            amount,
            msgGasLimit
        );

        (uint256 packetId, ) = _attesterChecks(accum);

        // ExecutionFailedBytes with out of gas
        vm.expectEmit(true, true, false, false);
        emit ExecutionFailedBytes(msgId, "0x");

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            msgGasLimit,
            accum,
            payload,
            proof
        );
    }

    function testExecuteWithExecutionFailure() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_SUB"), amount);
        bytes memory proof = abi.encode(0);
        uint256 msgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        hoax(_raju);
        srcCounter__.remoteSubOperation{value: minFees}(
            _b.chainId,
            amount,
            _msgGasLimit
        );

        (uint256 packetId, ) = _attesterChecks(accum);

        // ExecutionFailed with error decoded as string
        vm.expectEmit(true, true, false, false);
        emit ExecutionFailed(msgId, "CounterMock: Subtraction Overflow");

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );
    }

    function testRemoteAddFromAtoBFastPath() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address accum = address(_a.fastAccum__);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            amount,
            _msgGasLimit
        );

        uint256 msgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        // add attesters
        address newAttester = vm.addr(uint256(10));
        hoax(_socketOwner);
        _b.notary__.grantAttesterRole(_a.chainId, newAttester);

        (uint256 packetId, bytes32 root) = _attesterChecks(accum);

        // get signature
        bytes memory sig;
        {
            bytes32 digest = keccak256(
                abi.encode(_a.chainId, _b.chainId, accum, packetId, root)
            );
            digest = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
            );

            (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(
                uint256(10),
                digest
            );
            sig = new bytes(65);
            bytes1 v32 = bytes1(sigV);

            assembly {
                mstore(add(sig, 96), v32)
                mstore(add(sig, 32), sigR)
                mstore(add(sig, 64), sigS)
            }
        }

        vm.expectRevert(ISocket.VerificationFailed.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        // attest
        hoax(newAttester);
        _b.notary__.confirmRoot(_a.chainId, accum, packetId, root, sig);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
    }

    function testRemoteAddFromAtoBSlowPath() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address accum = address(_a.slowAccum__);
        _configPlugContracts(false);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainId,
            amount,
            _msgGasLimit
        );

        uint256 msgId = (uint256(uint160(address(srcCounter__))) << 96) |
            (_a.chainId << 80) |
            (_b.chainId << 64) |
            0;

        (uint256 packetId, ) = _attesterChecks(accum);

        vm.expectRevert(ISocket.VerificationFailed.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        vm.warp(block.timestamp + _slowAccumWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            accum,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcCounter__ = new Counter(address(_a.socket__));
        dstCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts(bool isFast_) internal {
        string memory integrationType = isFast_
            ? fastIntegrationType
            : slowIntegrationType;

        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainId,
            address(dstCounter__),
            integrationType
        );

        hoax(_plugOwner);
        dstCounter__.setSocketConfig(
            _a.chainId,
            address(srcCounter__),
            integrationType
        );
    }

    function _attesterChecks(address accum)
        internal
        returns (uint256 packetId, bytes32 root)
    {
        bytes memory sig;
        (root, packetId, sig) = _getLatestSignature(_a, accum, _b.chainId);
        _sealOnSrc(_a, accum, sig);
        _submitRootOnDst(_a, _b, sig, packetId, root, accum);
    }
}
