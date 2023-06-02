// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    bytes32 packetId;
    uint256 nonce;
    bytes32 root = bytes32(uint256(1));
    event SwitchboardTripped(bool tripGlobalFuse_);
    event PathTripped(uint32 srcChainSlug, bool tripSinglePath);
    event ProposalAttested(
        bytes32 packetId,
        uint256 proposalCount,
        bytes32 root,
        address attester,
        uint256 attestationsCount
    );
    event ProposalTripped(bytes32 packetId, uint256 proposalCount);

    error WatcherFound();
    error WatcherNotFound();
    error AlreadyAttested();
    error InvalidSigLength();
    error InvalidRoot();
    error NoPermit(bytes32 role);
    FastSwitchboard fastSwitchboard;

    function setUp() external {
        initialise();
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPivateKeys);

        packetId = bytes32(uint256(_a.chainSlug) << 224);

        bytes32 digest = keccak256(
            abi.encode(versionHash, _b.chainSlug, packetId, root)
        );
        bytes memory sig_ = _createSignature(digest, _transmitterPrivateKey);
        _proposeOnDst(_b, sig_, packetId, root);

        assertEq(_b.socket__.packetIdRoots(packetId, 0), root);

        vm.startPrank(_socketOwner);

        // fastSwitchboard = FastSwitchboard(
        //     address(_b.configs__[0].switchboard__)
        // );

        fastSwitchboard = new FastSwitchboard(
            _socketOwner,
            address(_b.socket__),
            _b.chainSlug,
            1,
            _a.sigVerifier__
        );

        fastSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        fastSwitchboard.grantWatcherRole(_a.chainSlug, _watcher);
        fastSwitchboard.grantWatcherRole(_a.chainSlug, _altWatcher);

        vm.stopPrank();
    }

    function signAndPropose(
        uint32 chainSlug_,
        bytes32 packetId_,
        bytes32 root_
    ) internal {
        bytes32 digest = keccak256(
            abi.encode(versionHash, chainSlug_, packetId_, root_)
        );
        bytes memory sig_ = _createSignature(digest, _transmitterPrivateKey);
        _proposeOnDst(_b, sig_, packetId, root_);
    }

    function testAttest() external {
        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 0, root, _watcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );
        assertTrue(fastSwitchboard.isAttested(_watcher, root));
    }

    function testAttestInvalidRoot() external {
        vm.expectRevert(InvalidRoot.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            1000, // Incorrect proposalCount
            _watcherPrivateKey
        );
    }

    function testDuplicateAttestation() external {
        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 0, root, _watcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );
        assertTrue(fastSwitchboard.isAttested(_watcher, root));

        vm.expectRevert(AlreadyAttested.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );
    }

    function testDuplicateAttestationOnDuplicateProposal() external {
        signAndPropose(_b.chainSlug, packetId, root);

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );
        vm.expectRevert(AlreadyAttested.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            1,
            _watcherPrivateKey
        );
    }

    function testAttestationOnDuplicateProposal() external {
        signAndPropose(_b.chainSlug, packetId, root);

        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 0, root, _watcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );

        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 1, root, _altWatcher, 2);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            1,
            _altWatcherPrivateKey
        );

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            0,
            _a.chainSlug,
            0
        );

        assertTrue(isAllowed);

        isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            1,
            _a.chainSlug,
            0
        );

        assertTrue(isAllowed);
    }

    function testRecoveryFromWrongProposal() external {
        bytes32 invalidRoot = bytes32(uint256(100));
        signAndPropose(_b.chainSlug, packetId, invalidRoot); // wrong root
        uint256 proposalCount = 1; // this is second proposal, 1st one proposed in setup

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PROPOSAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                packetId,
                proposalCount,
                _b.chainSlug,
                fastSwitchboard.nextNonce(_watcher)
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        fastSwitchboard.tripProposal(
            fastSwitchboard.nextNonce(_watcher),
            packetId,
            proposalCount,
            sig
        );

        assertTrue(fastSwitchboard.isProposalTripped(packetId, proposalCount));

        signAndPropose(_b.chainSlug, packetId, root); // wrong root
        proposalCount = 2;

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            _watcherPrivateKey
        );

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            _altWatcherPrivateKey
        );

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            proposalCount,
            _a.chainSlug,
            0
        );

        assertTrue(isAllowed);
    }

    function testIsAllowed() external {
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _altWatcherPrivateKey
        );

        uint256 proposeTime = block.timestamp -
            fastSwitchboard.timeoutInSeconds();

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            0,
            _a.chainSlug,
            proposeTime
        );

        assertTrue(isAllowed);
    }

    function testAttestationOnMultipleProposal() external {
        bytes32 digest = keccak256(
            abi.encode(versionHash, _b.chainSlug, packetId, root)
        );
        bytes memory sig_ = _createSignature(digest, _transmitterPrivateKey);
        _proposeOnDst(_b, sig_, packetId, root);

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _watcherPrivateKey
        );
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            _altWatcherPrivateKey
        );

        uint256 proposeTime = block.timestamp -
            fastSwitchboard.timeoutInSeconds();

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            0,
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
                _b.chainSlug,
                fastSwitchboard.nextNonce(_watcher),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        fastSwitchboard.tripGlobal(fastSwitchboard.nextNonce(_watcher), sig);
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);

        fastSwitchboard.grantWatcherRole(_a.chainSlug, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                _b.chainSlug,
                fastSwitchboard.nextNonce(_watcher),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(_a.chainSlug, true);
        fastSwitchboard.tripPath(
            fastSwitchboard.nextNonce(_watcher),
            _a.chainSlug,
            sig
        );
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripSinglePath(_a.chainSlug));
    }

    function testTripProposal() external {
        uint256 proposalCount;
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            _watcherPrivateKey
        );
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            _altWatcherPrivateKey
        );

        assertTrue(
            fastSwitchboard.allowPacket(
                root,
                packetId,
                proposalCount,
                _a.chainSlug,
                0
            )
        );
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PROPOSAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                packetId,
                proposalCount,
                _b.chainSlug,
                fastSwitchboard.nextNonce(_watcher)
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit ProposalTripped(packetId, proposalCount);
        fastSwitchboard.tripProposal(
            fastSwitchboard.nextNonce(_watcher),
            packetId,
            proposalCount,
            sig
        );

        assertFalse(
            fastSwitchboard.allowPacket(
                root,
                packetId,
                proposalCount,
                _a.chainSlug,
                0
            )
        );

        assertTrue(fastSwitchboard.isProposalTripped(packetId, proposalCount));
    }

    function testFailNonWatcherToTripPath() external {
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                _b.chainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        // vm.expectRevert();
        fastSwitchboard.tripPath(
            fastSwitchboard.nextNonce(_socketOwner),
            _a.chainSlug,
            sig
        );
    }

    function testUnTripAfterTripSingle() external {
        vm.startPrank(_socketOwner);
        fastSwitchboard.grantWatcherRole(_a.chainSlug, _socketOwner);
        fastSwitchboard.grantRole(UNTRIP_ROLE, _socketOwner);
        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                _b.chainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(_a.chainSlug, true);
        fastSwitchboard.tripPath(
            fastSwitchboard.nextNonce(_socketOwner),
            _a.chainSlug,
            sig
        );
        assertTrue(fastSwitchboard.tripSinglePath(_a.chainSlug));

        digest = keccak256(
            abi.encode(
                UNTRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _b.chainSlug,
                _a.chainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(_a.chainSlug, false);
        fastSwitchboard.untripPath(
            fastSwitchboard.nextNonce(_socketOwner),
            _a.chainSlug,
            sig
        );
        assertFalse(fastSwitchboard.tripSinglePath(_a.chainSlug));
    }

    function testGrantWatcherRole() external {
        uint256 watcher2PrivateKey = c++;
        address watcher2 = vm.addr(watcher2PrivateKey);

        vm.startPrank(_socketOwner);
        fastSwitchboard.grantWatcherRole(_a.chainSlug, watcher2);
        vm.stopPrank();

        assertEq(fastSwitchboard.totalWatchers(_a.chainSlug), 3);
    }

    function testRedundantGrantWatcherRole() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherFound.selector);
        fastSwitchboard.grantWatcherRole(_a.chainSlug, _watcher);

        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        fastSwitchboard.revokeWatcherRole(
            _a.chainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();

        assertEq(fastSwitchboard.totalWatchers(_a.chainSlug), 1);
    }

    function testRevokeWatcherRoleFail() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherNotFound.selector);
        fastSwitchboard.revokeWatcherRole(_a.chainSlug, vm.addr(c++));
        vm.stopPrank();
    }

    function testInvalidSignature() public {
        bytes memory sig = "0x121234323123232323";

        vm.expectRevert(InvalidSigLength.selector);
        fastSwitchboard.attest(packetId, 0, sig);
    }

    function testAttesterCantAttestAllChains() public {
        // Packet is coming from a chain different from _a.chainSlug
        bytes32 altPacketId = bytes32(uint256(_b.chainSlug) << 224);

        // to avoid invalidRoot error while attesting
        bytes32 digest = keccak256(
            abi.encode(versionHash, _b.chainSlug, altPacketId, root)
        );
        bytes memory sig_ = _createSignature(digest, _transmitterPrivateKey);
        _proposeOnDst(_b, sig_, altPacketId, root);

        vm.expectRevert(WatcherNotFound.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            altPacketId,
            0,
            _watcherPrivateKey
        );
    }
}
