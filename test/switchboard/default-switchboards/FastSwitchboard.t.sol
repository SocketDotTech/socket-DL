// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    uint32 remoteChainSlug;
    bytes32 packetId;
    address watcher;
    address altWatcher;
    uint256 nonce;

    event PacketAttested(bytes32 packetId, address attester);
    event SwitchboardTripped(bool tripGlobalFuse_);
    event PathTripped(uint32 srcChainSlug, bool tripSinglePath);

    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();
    error InvalidSigLength();

    FastSwitchboard fastSwitchboard;

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(c++);
        remoteChainSlug = uint32(c++);
        packetId = bytes32(uint256(remoteChainSlug) << 224);
        vm.startPrank(_socketOwner);

        fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(uint160(c++)),
            address(uint160(c++)),
            _a.chainSlug,
            1,
            _a.sigVerifier__
        );

        fastSwitchboard.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            remoteChainSlug,
            _socketOwner
        );
        fastSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        watcher = vm.addr(_watcherPrivateKey);
        altWatcher = vm.addr(_altWatcherPrivateKey);

        fastSwitchboard.grantWatcherRole(remoteChainSlug, watcher);
        fastSwitchboard.grantWatcherRole(remoteChainSlug, altWatcher);

        vm.stopPrank();
    }

    function testAttest() external {
        bytes32 digest = keccak256(
            abi.encode(
                address(fastSwitchboard),
                remoteChainSlug,
                _a.chainSlug,
                packetId
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PacketAttested(packetId, watcher);

        fastSwitchboard.attest(packetId, sig);

        assertTrue(fastSwitchboard.isAttested(watcher, packetId));
    }

    function testDuplicateAttestation() external {
        bytes32 digest = keccak256(
            abi.encode(
                address(fastSwitchboard),
                remoteChainSlug,
                _a.chainSlug,
                packetId
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PacketAttested(packetId, watcher);

        fastSwitchboard.attest(packetId, sig);

        assertTrue(fastSwitchboard.isAttested(watcher, packetId));

        vm.expectRevert(AlreadyAttested.selector);
        fastSwitchboard.attest(packetId, sig);
    }

    function testIsAllowed() external {
        bytes32 digest = keccak256(
            abi.encode(
                address(fastSwitchboard),
                remoteChainSlug,
                _a.chainSlug,
                packetId
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        fastSwitchboard.attest(packetId, sig);

        digest = keccak256(
            abi.encode(
                address(fastSwitchboard),
                remoteChainSlug,
                _a.chainSlug,
                packetId
            )
        );
        sig = _createSignature(digest, _altWatcherPrivateKey);

        fastSwitchboard.attest(packetId, sig);

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

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_GLOBAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                nonce,
                true
            )
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

        uint32 srcChainSlug = uint32(123);
        fastSwitchboard.grantRoleWithSlug(
            WATCHER_ROLE,
            srcChainSlug,
            _socketOwner
        );

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                srcChainSlug,
                _a.chainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(nonce++, srcChainSlug, sig);
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));
    }

    function testNonWatcherToTripPath() external {
        uint32 srcChainSlug = _a.chainSlug;
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                srcChainSlug,
                nonce,
                false
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectRevert();
        fastSwitchboard.tripPath(nonce++, srcChainSlug, sig);
    }

    function testUnTripAfterTripSingle() external {
        uint32 srcChainSlug = uint32(123);

        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRoleWithSlug(
            WATCHER_ROLE,
            srcChainSlug,
            _socketOwner
        );
        fastSwitchboard.grantRole(UNTRIP_ROLE, _socketOwner);
        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                srcChainSlug,
                _a.chainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        fastSwitchboard.tripPath(nonce++, srcChainSlug, sig);
        assertTrue(fastSwitchboard.tripSinglePath(srcChainSlug));

        digest = keccak256(
            abi.encode(
                UNTRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                srcChainSlug,
                nonce,
                false
            )
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
        fastSwitchboard.attest(packetId, sig);
    }

    function testAttesterCantAttestAllChains() public {
        // Packet is coming from a chain different from remoteChainSlug
        bytes32 altPacketId = bytes32(uint256(100) << 224);

        bytes32 digest = keccak256(
            abi.encode(
                address(fastSwitchboard),
                remoteChainSlug,
                _a.chainSlug,
                altPacketId
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectRevert(WatcherNotFound.selector);
        fastSwitchboard.attest(altPacketId, sig);
    }
}
