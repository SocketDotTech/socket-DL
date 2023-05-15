// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract OptimisticSwitchboardTest is Setup {
    bool isFast = true;
    uint32 immutable remoteChainSlug = uint32(uint256(2));
    uint256 immutable packetId = 1;
    address watcher;
    uint256 nonce;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event PathTripped(uint32 srcChainSlug, bool tripSinglePath);

    error WatcherFound();
    error WatcherNotFound();

    OptimisticSwitchboard optimisticSwitchboard;

    function setUp() external {
        initialise();
        _a.chainSlug = uint32(uint256(1));
        watcher = vm.addr(_watcherPrivateKey);

        vm.startPrank(_socketOwner);

        optimisticSwitchboard = new OptimisticSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            address(uint160(c++)),
            _a.chainSlug,
            1
        );

        optimisticSwitchboard.grantRole(
            "GAS_LIMIT_UPDATER_ROLE",
            remoteChainSlug,
            _socketOwner
        );
        optimisticSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                "EXECUTION_OVERHEAD_UPDATE",
                nonce,
                _a.chainSlug,
                remoteChainSlug,
                _executionOverhead
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        optimisticSwitchboard.setExecutionOverhead(
            nonce++,
            remoteChainSlug,
            _executionOverhead,
            sig
        );

        optimisticSwitchboard.grantRole(
            "WATCHER_ROLE",
            remoteChainSlug,
            watcher
        );
        optimisticSwitchboard.grantRole("WATCHER_ROLE", _a.chainSlug, watcher);
        optimisticSwitchboard.grantRole(
            "WATCHER_ROLE",
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );

        vm.stopPrank();
    }

    function testTripGlobal() external {
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.grantRole("TRIP_ROLE", _socketOwner);

        bytes32 digest = keccak256(
            abi.encode("TRIP", _a.chainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        optimisticSwitchboard.tripGlobal(nonce++, sig);
        vm.stopPrank();
        assertTrue(optimisticSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);
        uint32 srcChainSlug = _a.chainSlug;
        optimisticSwitchboard.grantRole(
            "WATCHER_ROLE",
            srcChainSlug,
            _socketOwner
        );

        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", _a.chainSlug, srcChainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(nonce++, srcChainSlug, sig);
        assertTrue(optimisticSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonWatcherToTripPath() external {
        uint32 srcChainSlug = _a.chainSlug;
        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", _a.chainSlug, srcChainSlug, nonce, false)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectRevert();
        optimisticSwitchboard.tripPath(nonce++, srcChainSlug, sig);
    }

    function testUnTripAfterTripSingle() external {
        uint32 srcChainSlug = _a.chainSlug;

        vm.startPrank(_socketOwner);
        optimisticSwitchboard.grantRole(
            "WATCHER_ROLE",
            srcChainSlug,
            _socketOwner
        );
        optimisticSwitchboard.grantRole("UNTRIP_ROLE", _socketOwner);
        vm.stopPrank();

        hoax(_socketOwner);
        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", _a.chainSlug, srcChainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(nonce++, srcChainSlug, sig);
        assertTrue(optimisticSwitchboard.tripSinglePath(srcChainSlug));

        hoax(_socketOwner);
        digest = keccak256(
            abi.encode("UNTRIP_PATH", _a.chainSlug, srcChainSlug, nonce, false)
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, false);
        optimisticSwitchboard.untripPath(nonce++, srcChainSlug, sig);
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
        optimisticSwitchboard.grantRole(
            "WATCHER_ROLE",
            srcChainSlug,
            _socketOwner
        );

        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", _a.chainSlug, srcChainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(nonce++, srcChainSlug, sig);

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
            "WATCHER_ROLE",
            remoteChainSlug,
            watcher2
        );
        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.revokeRole(
            "WATCHER_ROLE",
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();
    }
}
