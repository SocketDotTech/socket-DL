// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";

contract FastSwitchboardTest is Setup {
    bool isFast = true;
    bytes32 root = bytes32("RANDOM_ROOT");

    bytes32 packetId;
    uint256 nonce;

    event GlobalTripChanged(bool isGlobalTipped_);
    event PathTripChanged(uint32 srcChainSlug, bool isPathTripped);
    event ProposalAttested(
        bytes32 packetId,
        uint256 proposalCount,
        bytes32 root,
        address watcher,
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
        initialize();
        _a.chainSlug = uint32(uint256(aChainSlug));
        _b.chainSlug = uint32(uint256(bChainSlug));

        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;
        _deployContractsOnSingleChain(
            _b,
            _a.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys
        );

        fastSwitchboard = FastSwitchboard(
            address(_b.configs__[0].switchboard__)
        );

        hoax(_socketOwner);
        fastSwitchboard.grantWatcherRole(aChainSlug, _altWatcher);

        // grant role to this contract to be able to call Socket
        vm.prank(_b.socket__.owner());
        _b.socket__.grantRole(SOCKET_RELAYER_ROLE, address(this));

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
            0,
            bytes32("WRONG_ROOT"),
            _watcherPrivateKey
        );

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
        uint256 proposeTime = block.timestamp;

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _watcherPrivateKey
        );
        assertEq(fastSwitchboard.attestations(root), 1);

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            packetId,
            0,
            _a.chainSlug,
            proposeTime
        );

        assertFalse(isAllowed);

        _attestOnDst(
            address(fastSwitchboard),
            _b.chainSlug,
            packetId,
            0,
            root,
            _altWatcherPrivateKey
        );
        assertEq(fastSwitchboard.attestations(root), 2);

        isAllowed = fastSwitchboard.allowPacket(
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

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = WATCHER_ROLE;
        uint32[] memory chainSlugs = new uint32[](1);
        chainSlugs[0] = aChainSlug;
        address[] memory watchers = new address[](1);
        watchers[0] = _watcher;
        vm.expectRevert(FastSwitchboard.InvalidRole.selector);
        fastSwitchboard.grantBatchRole(roles, chainSlugs, watchers);

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

        vm.expectRevert(FastSwitchboard.InvalidRole.selector);
        fastSwitchboard.revokeRole(
            keccak256(abi.encode(WATCHER_ROLE, aChainSlug)),
            _watcher
        );

        vm.expectRevert(FastSwitchboard.InvalidRole.selector);
        fastSwitchboard.revokeRoleWithSlug(WATCHER_ROLE, aChainSlug, _watcher);

        bytes32[] memory roles = new bytes32[](1);
        roles[0] = WATCHER_ROLE;
        uint32[] memory chainSlugs = new uint32[](1);
        chainSlugs[0] = aChainSlug;
        address[] memory watchers = new address[](1);
        watchers[0] = _watcher;
        vm.expectRevert(FastSwitchboard.InvalidRole.selector);
        fastSwitchboard.revokeBatchRole(roles, chainSlugs, watchers);

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

    function testInvalidPacketCount() external {
        uint32 newSibling = uint32(c++);

        uint256 initialPacketCount = 100;
        bytes32 invalidPacketId = bytes32(
            (uint256(newSibling) << 224) | (uint256(uint160(c++)) << 64) | 1
        );
        bytes32 validPacketId = bytes32(
            (uint256(newSibling) << 224) |
                (uint256(uint160(c++)) << 64) |
                (initialPacketCount + 1)
        );

        skip(100);
        uint256 proposeTime = block.timestamp - 10;

        hoax(_socketOwner);
        fastSwitchboard.registerSiblingSlug(
            newSibling,
            DEFAULT_BATCH_LENGTH,
            1,
            initialPacketCount,
            address(uint160(c++))
        );

        bool isAllowed = fastSwitchboard.allowPacket(
            root,
            invalidPacketId,
            0,
            newSibling,
            proposeTime
        );

        assertFalse(isAllowed);

        isAllowed = fastSwitchboard.allowPacket(
            root,
            validPacketId,
            0,
            newSibling,
            proposeTime
        );

        assertTrue(isAllowed);
    }
}
