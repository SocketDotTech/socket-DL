// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";
import "../src/examples/Counter.sol";

contract DualChainTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;
    uint256 minFees = 10000;
    uint256 addAmount = 100;
    uint256 subAmount = 40;
    bool isFast = true;

    uint256 amount = 100;
    bytes proof = abi.encode(0);
    bytes payload = abi.encode(keccak256("OP_ADD"), amount);

    // the identifiers of the forks
    uint256 aFork;
    uint256 bFork;

    function setUp() public {
        _a.chainSlug = 1;
        _b.chainSlug = 2;

        aFork = vm.createFork(vm.envString("CHAIN1_RPC_URL"));
        bFork = vm.createFork(vm.envString("CHAIN2_RPC_URL"));

        uint256[] memory attesters = new uint256[](1);
        attesters[0] = _attesterPrivateKey;

        vm.selectFork(aFork);
        _a = _deployContractsOnSingleChain(_a.chainSlug, _b.chainSlug);
        _addAttesters(attesters, _a, _b.chainSlug);
        _setConfig(_a, _b.chainSlug);

        vm.selectFork(bFork);
        _b = _deployContractsOnSingleChain(_b.chainSlug, _a.chainSlug);
        _addAttesters(attesters, _b, _a.chainSlug);
        _setConfig(_b, _a.chainSlug);

        _deployPlugContracts();
        _configPlugContracts();
    }

    function testFork() external {
        address accum = isFast
            ? address(_a.fastAccum__)
            : address(_a.slowAccum__);

        hoax(_raju);
        vm.selectFork(aFork);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );

        uint256 msgId = _packMessageId(
            address(srcCounter__),
            _a.chainSlug,
            _b.chainSlug,
            0
        );

        (
            bytes32 root,
            uint256 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, accum, _b.chainSlug);
        _sealOnSrc(_a, accum, sig);

        vm.selectFork(bFork);
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

        assertEq(dstCounter__.counter(), amount);

        vm.selectFork(aFork);
        assertEq(srcCounter__.counter(), 0);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        vm.selectFork(aFork);
        srcCounter__ = new Counter(address(_a.socket__));

        vm.selectFork(bFork);
        dstCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts() internal {
        vm.startPrank(_plugOwner);

        string memory integrationType = isFast
            ? fastIntegrationType
            : slowIntegrationType;

        vm.selectFork(aFork);
        srcCounter__.setSocketConfig(
            _b.chainSlug,
            address(dstCounter__),
            integrationType
        );

        vm.selectFork(bFork);
        dstCounter__.setSocketConfig(
            _a.chainSlug,
            address(srcCounter__),
            integrationType
        );

        vm.stopPrank();
    }
}
