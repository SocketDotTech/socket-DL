// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";

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

        packetId = _getPackedId(address(uint160(c++)), aChainSlug, 0);
        _signAndPropose(_b, packetId, root);
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

        nonce = fastSwitchboard.nextNonce(_socketOwner);

        vm.expectEmit(false, false, false, true);
        emit GlobalTripChanged(true);
        fastSwitchboard.tripGlobal(nonce, sig);

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.tripGlobal(nonce, sig);
        vm.stopPrank();

        assertTrue(fastSwitchboard.isGlobalTipped());
        assertFalse(
            fastSwitchboard.allowPacket(root, packetId, 0, _a.chainSlug, 100)
        );
    }

    function testUntripGlobal() external {
        hoax(_socketOwner);
        fastSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        nonce = fastSwitchboard.nextNonce(_socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_GLOBAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _b.chainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        fastSwitchboard.tripGlobal(nonce, sig);
        assertTrue(fastSwitchboard.isGlobalTipped());

        nonce = fastSwitchboard.nextNonce(_socketOwner);

        digest = keccak256(
            abi.encode(
                UN_TRIP_GLOBAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
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
        fastSwitchboard.unTrip(nonce, sig);

        hoax(_socketOwner);
        fastSwitchboard.grantRole(UN_TRIP_ROLE, _socketOwner);
        fastSwitchboard.unTrip(nonce, sig);

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.unTrip(nonce, sig);
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

        nonce = fastSwitchboard.nextNonce(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit PathTripChanged(aChainSlug, true);
        fastSwitchboard.tripPath(nonce, aChainSlug, sig);

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.tripPath(nonce, aChainSlug, sig);

        vm.stopPrank();

        assertTrue(fastSwitchboard.isPathTripped(aChainSlug));
        assertFalse(
            fastSwitchboard.allowPacket(root, packetId, 0, _a.chainSlug, 100)
        );
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
        nonce = fastSwitchboard.nextNonce(_watcher);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PROPOSAL_SIG_IDENTIFIER,
                address(fastSwitchboard),
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
        fastSwitchboard.tripProposal(nonce, packetId, proposalCount, sig);

        // return false if the specific packet proposal is tripped
        assertFalse(
            fastSwitchboard.allowPacket(
                root,
                packetId,
                proposalCount,
                _a.chainSlug,
                block.timestamp
            )
        );

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.tripProposal(nonce, packetId, proposalCount, sig);
        assertTrue(fastSwitchboard.isProposalTripped(packetId, proposalCount));
    }

    function testNonWatcherToTripPath() external {
        nonce = fastSwitchboard.nextNonce(_socketOwner);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
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
        fastSwitchboard.tripPath(nonce, _a.chainSlug, sig);
    }

    function testUnTripAfterTripSingle() external {
        vm.startPrank(_socketOwner);
        fastSwitchboard.grantWatcherRole(aChainSlug, _socketOwner);
        fastSwitchboard.grantRole(UN_TRIP_ROLE, _socketOwner);
        vm.stopPrank();

        nonce = fastSwitchboard.nextNonce(_socketOwner);
        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripChanged(aChainSlug, true);
        fastSwitchboard.tripPath(nonce, aChainSlug, sig);
        assertTrue(fastSwitchboard.isPathTripped(aChainSlug));

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.tripPath(nonce, aChainSlug, sig);

        nonce = fastSwitchboard.nextNonce(_socketOwner);
        digest = keccak256(
            abi.encode(
                UN_TRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripChanged(aChainSlug, false);
        fastSwitchboard.unTripPath(nonce, aChainSlug, sig);
        assertFalse(fastSwitchboard.isPathTripped(aChainSlug));

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.unTripPath(nonce, aChainSlug, sig);
    }

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

    function testWithdrawFees() public {
        uint256 amount = 1e18;

        vm.startPrank(_socketOwner);
        vm.deal(address(fastSwitchboard), amount);
        uint256 initialBal = _fundRescuer.balance;

        vm.expectRevert(ZeroAddress.selector);
        fastSwitchboard.withdrawFees(address(0));

        fastSwitchboard.withdrawFees(_fundRescuer);

        assertEq(address(fastSwitchboard).balance, 0);
        assertEq(_fundRescuer.balance, initialBal + amount);

        vm.stopPrank();
    }
}
