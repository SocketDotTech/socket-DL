// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";

// covers tests for both fast and optimistic switchboard
contract SwitchboardBaseTest is Setup {
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
    FastSwitchboard defaultSwitchboard;

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

        defaultSwitchboard = FastSwitchboard(
            address(_b.configs__[0].switchboard__)
        );

        hoax(_socketOwner);
        defaultSwitchboard.grantWatcherRole(aChainSlug, _altWatcher);

        // grant role to this contract to be able to call Socket
        vm.prank(_b.socket__.owner());
        _b.socket__.grantRole(SOCKET_RELAYER_ROLE, address(this));
        
        packetId = _getPackedId(address(uint160(c++)), aChainSlug, 0);
        _signAndPropose(_b, packetId, root);
    }

    function testIsAllowedWhenProposedAfterTimeout() external {
        uint256 proposeTime = block.timestamp;
        bool isAllowed = defaultSwitchboard.allowPacket(
            0,
            0,
            0,
            _a.chainSlug,
            proposeTime
        );
        assertFalse(isAllowed);

        proposeTime =
            block.timestamp -
            defaultSwitchboard.timeoutInSeconds() -
            1;

        isAllowed = defaultSwitchboard.allowPacket(
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
        defaultSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_GLOBAL_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _b.chainSlug,
                defaultSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        nonce = defaultSwitchboard.nextNonce(_socketOwner);

        vm.expectEmit(false, false, false, true);
        emit GlobalTripChanged(true);
        defaultSwitchboard.tripGlobal(nonce, sig);

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        defaultSwitchboard.tripGlobal(nonce, sig);
        vm.stopPrank();

        assertTrue(defaultSwitchboard.isGlobalTipped());
        assertFalse(
            defaultSwitchboard.allowPacket(root, packetId, 0, _a.chainSlug, 100)
        );
    }

    function testUntripGlobal() external {
        hoax(_socketOwner);
        defaultSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        nonce = defaultSwitchboard.nextNonce(_socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_GLOBAL_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _b.chainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        defaultSwitchboard.tripGlobal(nonce, sig);
        assertTrue(defaultSwitchboard.isGlobalTipped());

        nonce = defaultSwitchboard.nextNonce(_socketOwner);

        digest = keccak256(
            abi.encode(
                UN_TRIP_GLOBAL_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _b.chainSlug,
                nonce,
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                UN_TRIP_ROLE
            )
        );
        defaultSwitchboard.unTrip(nonce, sig);

        hoax(_socketOwner);
        defaultSwitchboard.grantRole(UN_TRIP_ROLE, _socketOwner);
        defaultSwitchboard.unTrip(nonce, sig);

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        defaultSwitchboard.unTrip(nonce, sig);
    }

    function testTripPath() external {
        vm.startPrank(_socketOwner);

        defaultSwitchboard.grantWatcherRole(aChainSlug, _socketOwner);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _a.chainSlug,
                bChainSlug,
                defaultSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        nonce = defaultSwitchboard.nextNonce(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripChanged(aChainSlug, true);
        defaultSwitchboard.tripPath(nonce, aChainSlug, sig);

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        defaultSwitchboard.tripPath(nonce, aChainSlug, sig);

        vm.stopPrank();

        assertTrue(defaultSwitchboard.isPathTripped(aChainSlug));
        assertFalse(
            defaultSwitchboard.allowPacket(root, packetId, 0, _a.chainSlug, 100)
        );
    }

    function testTripProposal() external {
        uint256 proposalCount;
        _attestOnDst(
            address(defaultSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _watcherPrivateKey
        );
        _attestOnDst(
            address(defaultSwitchboard),
            _b.chainSlug,
            packetId,
            proposalCount,
            root,
            _altWatcherPrivateKey
        );

        assertTrue(
            defaultSwitchboard.allowPacket(
                root,
                packetId,
                proposalCount,
                _a.chainSlug,
                block.timestamp
            )
        );
        nonce = defaultSwitchboard.nextNonce(_watcher);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PROPOSAL_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                packetId,
                proposalCount
            )
        );
        bytes memory sig = _createSignature(digest, _watcherPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit ProposalTripped(packetId, proposalCount);
        defaultSwitchboard.tripProposal(nonce, packetId, proposalCount, sig);

        // return false if the specific packet proposal is tripped
        assertFalse(
            defaultSwitchboard.allowPacket(
                root,
                packetId,
                proposalCount,
                _a.chainSlug,
                block.timestamp
            )
        );

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        defaultSwitchboard.tripProposal(nonce, packetId, proposalCount, sig);
        assertTrue(
            defaultSwitchboard.isProposalTripped(packetId, proposalCount)
        );
    }

    function testNonWatcherToTripPath() external {
        nonce = defaultSwitchboard.nextNonce(_socketOwner);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                NoPermit.selector,
                keccak256(abi.encode(WATCHER_ROLE, _a.chainSlug))
            )
        );
        defaultSwitchboard.tripPath(nonce, _a.chainSlug, sig);
    }

    function testUnTripAfterTripSingle() external {
        vm.startPrank(_socketOwner);
        defaultSwitchboard.grantWatcherRole(aChainSlug, _socketOwner);
        defaultSwitchboard.grantRole(UN_TRIP_ROLE, _socketOwner);
        vm.stopPrank();

        nonce = defaultSwitchboard.nextNonce(_socketOwner);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripChanged(aChainSlug, true);
        defaultSwitchboard.tripPath(nonce, aChainSlug, sig);
        assertTrue(defaultSwitchboard.isPathTripped(aChainSlug));

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        defaultSwitchboard.tripPath(nonce, aChainSlug, sig);

        nonce = defaultSwitchboard.nextNonce(_socketOwner);
        digest = keccak256(
            abi.encode(
                UN_TRIP_PATH_SIG_IDENTIFIER,
                address(defaultSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripChanged(aChainSlug, false);
        defaultSwitchboard.unTripPath(nonce, aChainSlug, sig);
        assertFalse(defaultSwitchboard.isPathTripped(aChainSlug));

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        defaultSwitchboard.unTripPath(nonce, aChainSlug, sig);
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(
            address(defaultSwitchboard),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
    }

    function testWithdrawFees() public {
        uint256 amount = 1e18;

        vm.startPrank(_socketOwner);
        vm.deal(address(defaultSwitchboard), amount);
        uint256 initialBal = _fundRescuer.balance;

        vm.expectRevert(ZeroAddress.selector);
        defaultSwitchboard.withdrawFees(address(0));

        defaultSwitchboard.withdrawFees(_fundRescuer);

        assertEq(address(defaultSwitchboard).balance, 0);
        assertEq(_fundRescuer.balance, initialBal + amount);

        vm.stopPrank();
    }
}
