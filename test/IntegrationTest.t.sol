// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../contracts/examples/Counter.sol";

contract HappyTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;
    bool isFast = true;

    event ExecutionSuccess(uint256 msgId);
    event ExecutionFailed(uint256 msgId, string result);
    event ExecutionFailedBytes(uint256 msgId, bytes result);

    function setUp() external {
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPivateKeys);
        _deployPlugContracts();
        _configPlugContracts(isFast);
    }

    function testRemoteAddFromAtoB() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);

        uint256 index = isFast ? 0 : 1;
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            uint256 switchboardFees = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_msgGasLimit, _b.chainSlug);

            executionFee = _a.configs__[index].switchboard__.getExecutionFees(
                _msgGasLimit,
                _b.chainSlug
            );

            uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);

            hoax(_raju);
            srcCounter__.remoteAddOperation{
                value: switchboardFees + socketFees
            }(_b.chainSlug, amount, _msgGasLimit);
        }

        uint256 msgId = _packMessageId(_a.chainSlug, 0);

        uint256 packetId;
        {
            (
                bytes32 root_,
                uint256 packetId_,
                bytes memory sig_
            ) = _getLatestSignature(_a, capacitor, _b.chainSlug);

            _sealOnSrc(_a, capacitor, sig_);
            _proposeOnDst(_b, sig_, packetId_, root_);

            vm.expectEmit(true, false, false, false);
            emit ExecutionSuccess(msgId);

            packetId = packetId_;
        }

        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            executionFee,
            payload,
            proof
        );

        assertEq(dstCounter__.counter(), amount);
        assertEq(srcCounter__.counter(), 0);
        assertTrue(_b.socket__.messageExecuted(msgId));

        vm.expectRevert(SocketDst.MessageAlreadyExecuted.selector);
        _executePayloadOnDst(
            _a,
            _b,
            address(dstCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            executionFee,
            payload,
            proof
        );
    }

    function testRemoteAddFromBtoA() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(keccak256("OP_ADD"), amount);
        bytes memory proof = abi.encode(0);
        address capacitor = isFast
            ? address(_b.configs__[0].capacitor__)
            : address(_b.configs__[1].capacitor__);

        uint256 minFees = _b.transmitManager__.getMinFees(_a.chainSlug);

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
        _proposeOnDst(_a, sig, packetId, root);

        _executePayloadOnDst(
            _b,
            _a,
            address(srcCounter__),
            packetId,
            msgId,
            _msgGasLimit,
            0,
            payload,
            proof
        );

        assertEq(srcCounter__.counter(), amount);
        assertEq(dstCounter__.counter(), 0);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcCounter__ = new Counter(address(_a.socket__));
        dstCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts(bool isFast_) internal {
        uint256 index = isFast_ ? 0 : 1;

        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainSlug,
            address(dstCounter__),
            address(_a.configs__[index].switchboard__)
        );

        hoax(_plugOwner);
        dstCounter__.setSocketConfig(
            _a.chainSlug,
            address(srcCounter__),
            address(_b.configs__[index].switchboard__)
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
        _proposeOnDst(_b, sig, packetId, root);
    }
}
