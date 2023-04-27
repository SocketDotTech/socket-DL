// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    uint256 immutable remoteChainSlug = uint32(uint256(2));
    bytes32 immutable packetId = bytes32(0);
    address watcher;
    address altWatcher;
    uint256 nonce;

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
        initialise();

        _a.chainSlug = uint32(uint256(1));
        vm.startPrank(_socketOwner);

        fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            address(uint160(c++)),
            _a.chainSlug,
            1
        );

        fastSwitchboard.grantRole(
            "GAS_LIMIT_UPDATER_ROLE",
            remoteChainSlug,
            _socketOwner
        );
        fastSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

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
        fastSwitchboard.setExecutionOverhead(
            nonce++,
            remoteChainSlug,
            _executionOverhead,
            sig
        );

        watcher = vm.addr(_watcherPrivateKey);
        altWatcher = vm.addr(_altWatcherPrivateKey);

        fastSwitchboard.grantWatcherRole(remoteChainSlug, watcher);
        fastSwitchboard.grantWatcherRole(remoteChainSlug, altWatcher);

        digest = keccak256(
            abi.encode(
                "ATTEST_GAS_LIMIT_UPDATE",
                _a.chainSlug,
                remoteChainSlug,
                nonce,
                _attestGasLimit
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit AttestGasLimitSet(remoteChainSlug, _attestGasLimit);
        fastSwitchboard.setAttestGasLimit(
            nonce++,
            remoteChainSlug,
            _attestGasLimit,
            sig
        );

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
        fastSwitchboard.grantRole("TRIP_ROLE", _socketOwner);

        bytes32 digest = keccak256(
            abi.encode("TRIP", _a.chainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        fastSwitchboard.tripGlobal(nonce++, sig);
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);

        uint256 srcChainSlug = uint256(123);
        fastSwitchboard.grantRole("WATCHER_ROLE", srcChainSlug, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", srcChainSlug, _a.chainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(nonce++, srcChainSlug, sig);
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonWatcherToTripPath() external {
        uint256 srcChainSlug = _a.chainSlug;
        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", _a.chainSlug, srcChainSlug, nonce, false)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectRevert();
        fastSwitchboard.tripPath(nonce++, srcChainSlug, sig);
    }

    function testUnTripAfterTripSingle() external {
        uint256 srcChainSlug = uint256(123);

        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRole("WATCHER_ROLE", srcChainSlug, _socketOwner);
        fastSwitchboard.grantRole("UNTRIP_ROLE", _socketOwner);
        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode("TRIP_PATH", srcChainSlug, _a.chainSlug, nonce, true)
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(nonce++, srcChainSlug, sig);
        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));

        digest = keccak256(
            abi.encode("UNTRIP_PATH", _a.chainSlug, srcChainSlug, nonce, false)
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, false);
        fastSwitchboard.untripPath(nonce++, srcChainSlug, sig);
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
