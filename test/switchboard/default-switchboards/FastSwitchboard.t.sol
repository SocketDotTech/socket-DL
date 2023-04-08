// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    uint256 immutable remoteChainSlug = uint32(uint256(2));
    bytes32 immutable packetId = bytes32(0);
    address watcher;
    address altWatcher;

    event AttestGasLimitSet(uint256 dstChainSlug_, uint256 attestGasLimit_);
    event PacketAttested(bytes32 packetId, address attester);
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
            1
        );

        fastSwitchboard.grantRole(GAS_LIMIT_UPDATER_ROLE, _socketOwner);
        fastSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        fastSwitchboard.setExecutionOverhead(
            remoteChainSlug,
            _executionOverhead
        );

        watcher = vm.addr(_watcherPrivateKey);
        altWatcher = vm.addr(_altWatcherPrivateKey);

        fastSwitchboard.grantWatcherRole(remoteChainSlug, watcher);
        fastSwitchboard.grantWatcherRole(remoteChainSlug, altWatcher);

        vm.expectEmit(false, false, false, true);
        emit AttestGasLimitSet(remoteChainSlug, _attestGasLimit);
        fastSwitchboard.setAttestGasLimit(remoteChainSlug, _attestGasLimit);

        vm.stopPrank();
    }

    function testAttest() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PacketAttested(packetId, watcher);

        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        assertTrue(fastSwitchboard.isAttested(watcher, packetId));
    }

    function testDuplicateAttestation() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PacketAttested(packetId, watcher);

        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        assertTrue(fastSwitchboard.isAttested(watcher, packetId));

        vm.expectRevert(AlreadyAttested.selector);
        fastSwitchboard.attest(packetId, remoteChainSlug, sig);
    }

    function testIsAllowed() external {
        bytes32 digest = keccak256(abi.encode(remoteChainSlug, packetId));
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        fastSwitchboard.attest(packetId, remoteChainSlug, sig);

        digest = keccak256(abi.encode(remoteChainSlug, packetId));
        sig = _createSignature(digest, _altWatcherPrivateKey);

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

    function testIsAllowedWhenProposedAfterTimeout() external {
        uint256 proposeTime = block.timestamp;
        bool isAllowed = fastSwitchboard.allowPacket(
            0,
            0,
            _a.chainSlug,
            proposeTime
        );
        assertFalse(isAllowed);
    }

    function testTripGlobal() external {
        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRole(TRIP_ROLE, _socketOwner);
        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        fastSwitchboard.tripGlobal();
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);

        uint256 srcChainSlug = _a.chainSlug;
        fastSwitchboard.grantRole(TRIP_ROLE, srcChainSlug, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(srcChainSlug);
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonWatcherToTripPath() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        fastSwitchboard.tripPath(srcChainSlug);
    }

    function testNonOwnerToTripSingle() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        fastSwitchboard.tripPath(srcChainSlug);
    }

    function testUnTripAfterTripSingle() external {
        uint256 srcChainSlug = _a.chainSlug;

        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRole(TRIP_ROLE, srcChainSlug, _socketOwner);
        fastSwitchboard.grantRole(UNTRIP_ROLE, _socketOwner);
        vm.stopPrank();

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(srcChainSlug);
        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, false);
        fastSwitchboard.untripPath(srcChainSlug);
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
