// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    uint256 immutable remoteChainSlug = uint32(uint256(2));
    uint256 immutable packetId = 1;
    address watcher;

    event AttestGasLimitSet(uint256 dstChainSlug_, uint256 attestGasLimit_);
    event PacketAttested(uint256 packetId, address attester);
    event SwitchboardTripped(bool tripGlobalFuse_);
    event PathTripped(uint256 srcChainSlug, bool tripSinglePath);

    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();
    error InvalidSigLength();

    FastSwitchboard fastSwitchboard;

    function setUp() external {
        _a.chainSlug = uint32(uint256(1));

        vm.startPrank(_socketOwner);

        fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            _timeoutInSeconds
        );

        fastSwitchboard.setExecutionOverhead(
            remoteChainSlug,
            _executionOverhead
        );

        watcher = vm.addr(_watcherPrivateKey);

        fastSwitchboard.grantWatcherRole(
            remoteChainSlug,
            vm.addr(_watcherPrivateKey)
        );
        fastSwitchboard.grantWatcherRole(
            _a.chainSlug,
            vm.addr(_watcherPrivateKey)
        );
        fastSwitchboard.grantWatcherRole(
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );

        vm.expectEmit(false, false, false, true);
        emit AttestGasLimitSet(remoteChainSlug, _attestGasLimit);
        fastSwitchboard.setAttestGasLimit(remoteChainSlug, _attestGasLimit);

        vm.stopPrank();
    }

    function testAttest() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));

        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PacketAttested(packetId, vm.addr(_watcherPrivateKey));

        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        assertTrue(
            fastSwitchboard.isAttested(vm.addr(_watcherPrivateKey), packetId)
        );
    }

    function testDuplicateAttestation() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));

        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PacketAttested(packetId, vm.addr(_watcherPrivateKey));

        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        assertTrue(
            fastSwitchboard.isAttested(vm.addr(_watcherPrivateKey), packetId)
        );

        vm.expectRevert(AlreadyAttested.selector);
        fastSwitchboard.attest(packetId, remoteChainSlug, sig);
    }

    function testIsAllowed() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));

        bytes memory sig = _createSignature(digest, _watcherPrivateKey);
        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        uint256 proposeTime = block.timestamp -
            fastSwitchboard.timeoutInSeconds();

        bool isAllowed = fastSwitchboard.allowPacket(
            0,
            packetId,
            _a.chainSlug,
            proposeTime
        );

        assertTrue(isAllowed);
    }

    function testTripGlobal() external {
        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        fastSwitchboard.trip(true);
        assertTrue(fastSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        hoax(watcher);
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(srcChainSlug);
        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonWatcherToTripPath() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        fastSwitchboard.tripPath(srcChainSlug);
    }

    function testTripSingle() external {
        hoax(_socketOwner);
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripSingle(srcChainSlug, true);
        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonOwnerToTripSingle() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        fastSwitchboard.tripSingle(srcChainSlug, true);
    }

    function testUnTripAfterTripSingle() external {
        hoax(_socketOwner);
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripSingle(srcChainSlug, true);
        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, false);
        fastSwitchboard.tripSingle(srcChainSlug, false);
        assertFalse(fastSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testGrantWatcherRole() external {
        uint256 watcher2PrivateKey = c++;
        address watcher2 = vm.addr(watcher2PrivateKey);

        vm.startPrank(_socketOwner);

        fastSwitchboard.grantWatcherRole(remoteChainSlug, watcher2);
        vm.stopPrank();

        assertEq(fastSwitchboard.totalWatchers(remoteChainSlug), 3);
    }

    function testRedundantGrantWatcherRole() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherFound.selector);
        fastSwitchboard.grantWatcherRole(remoteChainSlug, watcher);

        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        fastSwitchboard.revokeWatcherRole(
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();

        assertEq(fastSwitchboard.totalWatchers(remoteChainSlug), 1);
    }

    function testRevokeWatcherRoleFail() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherNotFound.selector);
        fastSwitchboard.revokeWatcherRole(remoteChainSlug, vm.addr(c++));
        vm.stopPrank();
    }

    function testInvalidSignature() public {
        bytes memory sig = "0x121234323123232323";

        vm.expectRevert(InvalidSigLength.selector);
        fastSwitchboard.attest(packetId, remoteChainSlug, sig);
    }
}
