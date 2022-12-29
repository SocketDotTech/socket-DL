// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../contracts/examples/Counter.sol";

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
        address capacitor = isFast
            ? address(_a.fastCapacitor__)
            : address(_a.slowCapacitor__);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );
        // TODO: get nonce from event

        uint256 msgId = _packMessageId(_a.chainSlug, 0);

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, capacitor, _b.chainSlug);
        address attester = vm.addr(_attesterPrivateKey);

        // not an attester
        {
            hoax(_socketOwner);
            _a.notary__.revokeAttesterRole(_b.chainSlug, attester);
            vm.expectRevert(INotary.InvalidAttester.selector);
            _sealOnSrc(_a, capacitor, sig);

            hoax(_socketOwner);
            _a.notary__.grantAttesterRole(_b.chainSlug, attester);
        }

        _sealOnSrc(_a, capacitor, sig);

        // revert execution if packet not proposed
        assertEq(uint256(_b.notary__.getPacketStatus(packetId)), 0);

        vm.expectRevert(SocketDst.VerificationFailed.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );

        _submitRootOnDst(_b, sig, packetId, root);

        vm.expectRevert(INotary.AlreadyAttested.selector);
        _submitRootOnDst(_b, sig, packetId, root);

        // without executor role
        {
            hoax(_socketOwner);
            _b.socket__.revokeExecutorRole(_raju);

            vm.expectRevert(SocketDst.ExecutorNotFound.selector);
            _executePayloadOnDst(
                _a,
                _b,
                address(dstCounter__),
                packetId,
                msgId,
                _msgGasLimit,
                payload,
                proof
            );

            hoax(_socketOwner);
            _b.socket__.grantExecutorRole(_raju);
        }

        assertEq(uint256(_b.socket__.messageStatus(msgId)), 0);

        vm.expectEmit(true, false, false, false);
        emit ExecutionSuccess(msgId);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
        assertEq(uint256(_b.socket__.messageStatus(msgId)), 1);

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );
    }

    function testRemoteAddFromBtoA() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address capacitor = isFast
            ? address(_b.fastCapacitor__)
            : address(_b.slowCapacitor__);

        hoax(_raju);
        dstCounter__.remoteAddOperation{value: minFees}(
            _a.chainSlug,
            amount,
            _msgGasLimit
        );

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_b, capacitor, _a.chainSlug);

        uint256 msgId = _packMessageId(_b.chainSlug, 0);
        _sealOnSrc(_b, capacitor, sig);
        _submitRootOnDst(_a, sig, packetId, root);

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
        assertEq(dstCounter__.counter(), 0);
    }

    function testRemoteAddAndSubtract() external {
        bytes memory addPayload = abi.encode(keccak256("OP_ADD"), addAmount);
        uint256 addMsgId = _packMessageId(_a.chainSlug, 0);

        bytes memory subPayload = abi.encode(keccak256("OP_SUB"), subAmount);
        uint256 subMsgId = _packMessageId(_a.chainSlug, 1);
        address capacitor = isFast
            ? address(_a.fastCapacitor__)
            : address(_a.slowCapacitor__);

        bytes32 root;
        uint256 packetId;
        bytes memory sig;

        hoax(_raju);
        vm.expectRevert(Vault.InsufficientFees.selector);
        srcCounter__.remoteAddOperation(_b.chainSlug, addAmount, _msgGasLimit);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            addAmount,
            _msgGasLimit
        );

        (root, packetId, sig) = _getLatestSignature(
            _a,
            capacitor,
            _b.chainSlug
        );
        _sealOnSrc(_a, capacitor, sig);
        _submitRootOnDst(_b, sig, packetId, root);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            addMsgId,
            _msgGasLimit,
            addPayload,
            abi.encode(0)
        );

        hoax(_raju);
        srcCounter__.remoteSubOperation{value: minFees}(
            _b.chainSlug,
            subAmount,
            _msgGasLimit
        );

        (root, packetId, sig) = _getLatestSignature(
            _a,
            capacitor,
            _b.chainSlug
        );
        _sealOnSrc(_a, capacitor, sig);
        _submitRootOnDst(_b, sig, packetId, root);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            subMsgId,
            _msgGasLimit,
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
        uint256 msgId = _packMessageId(_a.chainSlug, 0);
        address capacitor = isFast
            ? address(_a.fastCapacitor__)
            : address(_a.slowCapacitor__);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );
        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, capacitor, _b.chainSlug);
        _sealOnSrc(_a, capacitor, sig);
        _submitRootOnDst(_b, sig, packetId, root);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
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
        uint256 msgId = _packMessageId(_a.chainSlug, 0);
        address capacitor = isFast
            ? address(_a.fastCapacitor__)
            : address(_a.slowCapacitor__);

        // providing a lower gas limit
        uint256 msgGasLimit = 1000;
        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            msgGasLimit
        );

        (uint256 packetId, ) = _attesterChecks(capacitor);

        assertEq(uint256(_b.socket__.messageStatus(msgId)), 0);

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
            payload,
            proof
        );

        assertEq(uint256(_b.socket__.messageStatus(msgId)), 2);
    }

    function testExecuteWithExecutionFailure() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_SUB"), amount);
        bytes memory proof = abi.encode(0);
        uint256 msgId = _packMessageId(_a.chainSlug, 0);
        address capacitor = isFast
            ? address(_a.fastCapacitor__)
            : address(_a.slowCapacitor__);

        hoax(_raju);
        srcCounter__.remoteSubOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );

        (uint256 packetId, ) = _attesterChecks(capacitor);
        assertEq(uint256(_b.socket__.messageStatus(msgId)), 0);

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
            payload,
            proof
        );

        assertEq(uint256(_b.socket__.messageStatus(msgId)), 2);
    }

    function testRemoteAddFromAtoBFastPath() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address capacitor = address(_a.fastCapacitor__);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );

        uint256 msgId = _packMessageId(_a.chainSlug, 0);

        // add attesters
        address newAttester = vm.addr(uint256(10));
        hoax(_socketOwner);
        _b.notary__.grantAttesterRole(_a.chainSlug, newAttester);

        (uint256 packetId, bytes32 root) = _attesterChecks(capacitor);

        // get signature
        bytes memory sig = _createSignature(
            _b.chainSlug,
            packetId,
            uint256(10),
            root
        );

        vm.expectRevert(SocketDst.VerificationFailed.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );

        // attest
        hoax(newAttester);
        _b.notary__.attest(packetId, root, sig);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
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
        address capacitor = address(_a.slowCapacitor__);
        _configPlugContracts(false);

        hoax(_raju);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );

        uint256 msgId = _packMessageId(_a.chainSlug, 0);

        (uint256 packetId, ) = _attesterChecks(capacitor);

        vm.expectRevert(SocketDst.VerificationFailed.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            payload,
            proof
        );

        vm.warp(block.timestamp + _slowCapacitorWaitTime);

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
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
            _b.chainSlug,
            address(dstCounter__),
            address(0) // integrationType // TODO: change to switchboard
        );

        hoax(_plugOwner);
        dstCounter__.setSocketConfig(
            _a.chainSlug,
            address(srcCounter__),
            address(0) // integrationType // TODO: change to switchboard
        );
    }

    function _attesterChecks(
        address capacitor
    ) internal returns (uint256 packetId, bytes32 root) {
        bytes memory sig;
        (root, packetId, sig) = _getLatestSignature(
            _a,
            capacitor,
            _b.chainSlug
        );
        _sealOnSrc(_a, capacitor, sig);
        _submitRootOnDst(_b, sig, packetId, root);
    }
}
