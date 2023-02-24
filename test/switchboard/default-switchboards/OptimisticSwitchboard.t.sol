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

        vm.startPrank(_socketOwner);

        optimisticSwitchboard = new OptimisticSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            _timeoutInSeconds
        );

        optimisticSwitchboard.setExecutionOverhead(
            remoteChainSlug,
            _executionOverhead
        );

        watcher = vm.addr(_watcherPrivateKey);

        optimisticSwitchboard.grantWatcherRole(
            remoteChainSlug,
            vm.addr(_watcherPrivateKey)
        );
        optimisticSwitchboard.grantWatcherRole(
            _a.chainSlug,
            vm.addr(_watcherPrivateKey)
        );
        optimisticSwitchboard.grantWatcherRole(
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );

        vm.stopPrank();
    }

    function testTripGlobal() external {
        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        optimisticSwitchboard.tripGlobal(true);
        assertTrue(optimisticSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        hoax(watcher);
        uint256 srcChainSlug = _a.chainSlug;
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

    function testTripSingle() external {
        hoax(_socketOwner);
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripSingle(srcChainSlug, true);
        assertTrue(optimisticSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonOwnerToTripSingle() external {
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectRevert();
        optimisticSwitchboard.tripSingle(srcChainSlug, true);
    }

    function testUnTripAfterTripSingle() external {
        hoax(_socketOwner);
        uint256 srcChainSlug = _a.chainSlug;
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripSingle(srcChainSlug, true);
        assertTrue(optimisticSwitchboard.tripSinglePath(srcChainSlug));

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, false);
        optimisticSwitchboard.tripSingle(srcChainSlug, false);
        assertFalse(optimisticSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testGrantWatcherRole() external {
        uint256 watcher2PrivateKey = c++;
        address watcher2 = vm.addr(watcher2PrivateKey);

        vm.startPrank(_socketOwner);

        optimisticSwitchboard.grantWatcherRole(remoteChainSlug, watcher2);
        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.revokeWatcherRole(
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();
    }

    function testRedundantGrantWatcherRole() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherFound.selector);
        optimisticSwitchboard.grantWatcherRole(remoteChainSlug, watcher);

        vm.stopPrank();
    }

    function testRevokeWatcherRoleFail() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherNotFound.selector);
        optimisticSwitchboard.revokeWatcherRole(remoteChainSlug, vm.addr(c++));
        vm.stopPrank();
    }
}
