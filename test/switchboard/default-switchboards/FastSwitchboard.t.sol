// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    bytes32 root = bytes32("RANDOM_ROOT");

    bytes32 packetId;
    uint256 nonce;

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
        _a.chainSlug = uint32(uint256(aChainSlug));
        _b.chainSlug = uint32(uint256(bChainSlug));

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;
        console.log(_transmitter);
        _deployContractsOnSingleChain(
            _b,
            _a.chainSlug,
            isExecutionOpen,
            transmitterPivateKeys
        );

        fastSwitchboard = FastSwitchboard(
            address(_b.configs__[0].switchboard__)
        );

        hoax(_socketOwner);
        fastSwitchboard.grantWatcherRole(aChainSlug, _altWatcher);

        packetId = _getPackedId(address(uint160(c++)), aChainSlug, 0);
        _signAndPropose(_b, packetId, root);
    }

    function testAttest() external {
        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 0, root, _watcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );
        assertTrue(fastSwitchboard.isAttested(_watcher, root));
        assertEq(fastSwitchboard.attestations(root), 1);
    }

    function testAttestInvalidRoot() external {
        vm.expectRevert(InvalidRoot.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            1000, // Incorrect proposalCount
            root,
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
            root,
            _watcherPrivateKey
        );
        assertTrue(fastSwitchboard.isAttested(_watcher, root));

        vm.expectRevert(AlreadyAttested.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );
    }

    function testDuplicateAttestationOnDuplicateProposal() external {
        _signAndPropose(_b, packetId, root);

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );
        vm.expectRevert(AlreadyAttested.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            1,
            root,
            _watcherPrivateKey
        );
    }

    function testAttestationOnDuplicateProposal() external {
        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 0, root, _watcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );

        assertEq(fastSwitchboard.attestations(root), 1);

        _signAndPropose(_b, packetId, root);
        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 1, root, _altWatcher, 2);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            1,
            root,
            _altWatcherPrivateKey
        );

        assertEq(fastSwitchboard.attestations(root), 2);

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            0,
            _a.chainSlug,
            block.timestamp
        );

        assertTrue(isAllowed);

        isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            1,
            _a.chainSlug,
            block.timestamp
        );

        assertTrue(isAllowed);
    }

    function testAttestationOnDifferentPackets() external {
        bytes32 root2 = keccak256(abi.encodePacked(bytes32("RANDOM_ROOT_2")));

        bytes32 altPacketId = _getPackedId(
            address(uint160(c++)),
            aChainSlug,
            0
        );
        _signAndPropose(_b, altPacketId, root2);

        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(packetId, 0, root, _watcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );

        vm.expectEmit(false, false, false, true);
        emit ProposalAttested(altPacketId, 0, root2, _altWatcher, 1);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            altPacketId,
            0,
            root2,
            _altWatcherPrivateKey
        );

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            0,
            _a.chainSlug,
            block.timestamp
        );

        assertFalse(isAllowed);

        isAllowed = fastSwitchboard.allowPacket(
            root,
            altPacketId,
            0,
            _a.chainSlug,
            block.timestamp
        );

        assertFalse(isAllowed);
    }

    function testRecoveryFromWrongProposal() external {
        bytes32 invalidRoot = bytes32(uint256(100));
        _signAndPropose(_b, packetId, invalidRoot); // wrong root
        uint256 proposalCount = 1; // this is second proposal, 1st one proposed in setup

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PROPOSAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                fastSwitchboard.nextNonce(_watcher),
                packetId,
                proposalCount
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

        _signAndPropose(_b, packetId, root); // wrong root
        proposalCount = 2;

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _altWatcherPrivateKey
        );

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            proposalCount,
            _a.chainSlug,
            block.timestamp
        );

        assertTrue(isAllowed);
    }

    function testIsAllowed() external {
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );
        assertEq(fastSwitchboard.attestations(root), 1);

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _altWatcherPrivateKey
        );
        assertEq(fastSwitchboard.attestations(root), 2);

        uint256 proposeTime = block.timestamp;

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
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _altWatcherPrivateKey
        );
        assertEq(fastSwitchboard.attestations(root), 2);

        uint256 proposeTime = block.timestamp;

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

        proposeTime = block.timestamp - fastSwitchboard.timeoutInSeconds() - 1;

        isAllowed = fastSwitchboard.allowPacket(
            0,
            0,
            0,
            _a.chainSlug,
            proposeTime
        );
        assertTrue(isAllowed);
    }

    function testTripGlobal() external {
        vm.startPrank(_socketOwner);
        fastSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_GLOBAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _b.chainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        fastSwitchboard.tripGlobal(
            fastSwitchboard.nextNonce(_socketOwner),
            sig
        );
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripGlobalFuse());
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);

        fastSwitchboard.grantWatcherRole(aChainSlug, _socketOwner);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(aChainSlug, true);
        fastSwitchboard.tripPath(
            fastSwitchboard.nextNonce(_socketOwner),
            aChainSlug,
            sig
        );
        vm.stopPrank();

        assertTrue(fastSwitchboard.tripSinglePath(aChainSlug));
    }

    function testTripProposal() external {
        uint256 proposalCount;
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _altWatcherPrivateKey
        );

        assertTrue(
            fastSwitchboard.allowPacket(
                root,
                packetId,
                proposalCount,
                _a.chainSlug,
                block.timestamp
            )
        );
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PROPOSAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                fastSwitchboard.nextNonce(_watcher),
                packetId,
                proposalCount
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
                block.timestamp
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
                bChainSlug,
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
        fastSwitchboard.grantWatcherRole(aChainSlug, _socketOwner);
        fastSwitchboard.grantRole(UNTRIP_ROLE, _socketOwner);
        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(aChainSlug, true);
        fastSwitchboard.tripPath(
            fastSwitchboard.nextNonce(_socketOwner),
            aChainSlug,
            sig
        );
        assertTrue(fastSwitchboard.tripSinglePath(aChainSlug));

        digest = keccak256(
            abi.encode(
                UNTRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                fastSwitchboard.nextNonce(_socketOwner),
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(aChainSlug, false);
        fastSwitchboard.untripPath(
            fastSwitchboard.nextNonce(_socketOwner),
            aChainSlug,
            sig
        );
        assertFalse(fastSwitchboard.tripSinglePath(aChainSlug));
    }

    function testGrantWatcherRole() external {
        uint256 watcher2PrivateKey = c++;
        address watcher2 = vm.addr(watcher2PrivateKey);

        vm.startPrank(_socketOwner);
        vm.expectRevert(FastSwitchboard.InvalidRole.selector);
        fastSwitchboard.grantRole(
            keccak256(abi.encode(WATCHER_ROLE, aChainSlug)),
            watcher2
        );

        vm.expectRevert(FastSwitchboard.InvalidRole.selector);
        fastSwitchboard.grantRoleWithSlug(WATCHER_ROLE, aChainSlug, watcher2);

        fastSwitchboard.grantWatcherRole(aChainSlug, watcher2);

        assertEq(fastSwitchboard.totalWatchers(aChainSlug), 3);
        vm.stopPrank();
    }

    function testRedundantGrantWatcherRole() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherFound.selector);
        fastSwitchboard.grantWatcherRole(aChainSlug, _watcher);

        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        fastSwitchboard.revokeWatcherRole(
            aChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();

        assertEq(fastSwitchboard.totalWatchers(aChainSlug), 1);
    }

    function testRevokeWatcherRoleFail() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert(WatcherNotFound.selector);
        fastSwitchboard.revokeWatcherRole(_a.chainSlug, vm.addr(c++));
        vm.stopPrank();
    }

    function testInvalidSignature() public {
        bytes memory sig = "0x121234323123232323";

        vm.expectRevert("ECDSA: invalid signature length");
        fastSwitchboard.attest(packetId, 0, root, sig);
    }

    function testAttesterCantAttestAllChains() public {
        // Packet is coming from a chain different from bChainSlug
        bytes32 altPacketId = bytes32(uint256(cChainSlug) << 224);

        // to avoid invalidRoot error while attesting
        bytes32 digest = keccak256(
            abi.encode(versionHash, _b.chainSlug, altPacketId, root)
        );
        bytes memory sig_ = _createSignature(digest, _transmitterPrivateKey);

        hoax(_socketOwner);
        _b.transmitManager__.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            cChainSlug,
            _transmitter
        );
        _proposeOnDst(
            _b,
            sig_,
            altPacketId,
            root,
            address(_b.configs__[0].switchboard__)
        );

        vm.expectRevert(WatcherNotFound.selector);
        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            altPacketId,
            0,
            root,
            _watcherPrivateKey
        );
    }

    // function testWithdrawFees() public {
    //     (uint256 minFees, ) = fastSwitchboard.getMinFees(bChainSlug);
    //     deal(_feesPayer, minFees);

    //     assertEq(address(fastSwitchboard).balance, 0);
    //     assertEq(_feesPayer.balance, minFees);

    //     vm.startPrank(_feesPayer);
    //     fastSwitchboard.payFees{value: minFees}(bChainSlug);
    //     vm.stopPrank();

    //     assertEq(_feesWithdrawer.balance, 0);

    //     hoax(_raju);
    //     vm.expectRevert();
    //     fastSwitchboard.withdrawFees(_feesWithdrawer);

    //     hoax(_socketOwner);
    //     fastSwitchboard.withdrawFees(_feesWithdrawer);

    //     assertEq(_feesWithdrawer.balance, minFees);
    // }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(
            address(fastSwitchboard),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
    }
}
