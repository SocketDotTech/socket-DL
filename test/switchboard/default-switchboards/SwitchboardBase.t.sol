// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

import "../../Setup.t.sol";

contract SwitchboardBaseTest is Setup {
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
        fastSwitchboard.tripProposal(
            nonce,
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
        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.tripProposal(
            nonce,
            packetId,
            proposalCount,
            sig
        );
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

        nonce = fastSwitchboard.nextNonce(_socketOwner);
        digest = keccak256(
            abi.encode(
                UNTRIP_PATH_SIG_IDENTIFIER,
                address(fastSwitchboard),
                _a.chainSlug,
                bChainSlug,
                nonce,
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(aChainSlug, false);
        fastSwitchboard.untripPath(nonce, aChainSlug, sig);
        assertFalse(fastSwitchboard.tripSinglePath(aChainSlug));

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        fastSwitchboard.untripPath(nonce, aChainSlug, sig);
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
}
