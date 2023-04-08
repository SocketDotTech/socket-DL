// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract OptimisticSwitchboardTest is Setup {
    bool isFast = true;
    uint256 immutable remoteChainSlug = uint32(uint256(2));
    uint256 immutable packetId = 1;
    address watcher;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event PathTripped(uint256 srcChainSlug, bool tripSinglePath);

    error WatcherFound();
    error WatcherNotFound();

    OptimisticSwitchboard optimisticSwitchboard;

    function setUp() external {
        _a.chainSlug = uint32(uint256(1));
        watcher = vm.addr(_watcherPrivateKey);

        vm.startPrank(_socketOwner);

        optimisticSwitchboard = new OptimisticSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            1
        );

        optimisticSwitchboard.grantRole(GAS_LIMIT_UPDATER_ROLE, _socketOwner);
        optimisticSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        optimisticSwitchboard.setExecutionOverhead(
            remoteChainSlug,
            _executionOverhead
        );

        optimisticSwitchboard.grantRole(WATCHER_ROLE, remoteChainSlug, watcher);
        optimisticSwitchboard.grantRole(WATCHER_ROLE, _a.chainSlug, watcher);
        optimisticSwitchboard.grantRole(
            WATCHER_ROLE,
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );

        vm.stopPrank();
    }

    function testTripGlobal() external {
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        optimisticSwitchboard.tripGlobal();
        vm.stopPrank();
        assertTrue(optimisticSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);
        uint256 srcChainSlug = _a.chainSlug;
        optimisticSwitchboard.grantRole(TRIP_ROLE, srcChainSlug, _socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(srcChainSlug);
        assertTrue(optimisticSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonWatcherToTripPath() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        optimisticSwitchboard.tripPath(srcChainSlug);
    }

    function testNonOwnerToTripSingle() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        optimisticSwitchboard.tripPath(srcChainSlug);
    }

    function testUnTripAfterTripSingle() external {
        uint256 srcChainSlug = _a.chainSlug;

        vm.startPrank(_socketOwner);
        optimisticSwitchboard.grantRole(TRIP_ROLE, srcChainSlug, _socketOwner);
        optimisticSwitchboard.grantRole(UNTRIP_ROLE, _socketOwner);
        vm.stopPrank();

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(srcChainSlug);
        assertTrue(optimisticSwitchboard.tripSinglePath(srcChainSlug));

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, false);
        optimisticSwitchboard.untripPath(srcChainSlug);
        assertFalse(optimisticSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testIsAllowed() external {
        uint256 proposeTime = block.timestamp -
            optimisticSwitchboard.timeoutInSeconds();

        bool isAllowed = optimisticSwitchboard.allowPacket(
            0,
            0,
            _a.chainSlug,
            proposeTime
        );

        assertTrue(isAllowed);
    }

    function testIsAllowedWhenProposedAfterTimeout() external {
        uint256 proposeTime = block.timestamp;
        bool isAllowed = optimisticSwitchboard.allowPacket(
            0,
            0,
            _a.chainSlug,
            proposeTime
        );
        assertFalse(isAllowed);
    }

    function testIsAllowedWhenAPathIsTrippedByOwner() external {
        uint256 proposeTime = block.timestamp -
            optimisticSwitchboard.timeoutInSeconds();

        vm.startPrank(_socketOwner);

        uint32 srcChainSlug = _a.chainSlug;
        optimisticSwitchboard.grantRole(TRIP_ROLE, srcChainSlug, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(srcChainSlug);

        bool isAllowed = optimisticSwitchboard.allowPacket(
            0,
            0,
            srcChainSlug,
            proposeTime
        );

        assertFalse(isAllowed);
    }

    function testGrantWatcherRole() external {
        uint256 watcher2PrivateKey = c++;
        address watcher2 = vm.addr(watcher2PrivateKey);

        vm.startPrank(_socketOwner);

        optimisticSwitchboard.grantRole(
            WATCHER_ROLE,
            remoteChainSlug,
            watcher2
        );
        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.revokeRole(
            WATCHER_ROLE,
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();
    }
}
