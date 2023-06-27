// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";

contract OptimisticSwitchboardTest is Setup {
    bool isFast = true;
    uint32 immutable remoteChainSlug = bChainSlug;

    bytes32 packetId;
    address watcher;
    uint256 nonce;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event PathTripped(uint32 srcChainSlug, bool tripSinglePath);

    error WatcherFound();
    error WatcherNotFound();
    error SwitchboardExists();
    OptimisticSwitchboard optimisticSwitchboard;

    function setUp() external {
        initialize();
        _a.chainSlug = uint32(uint256(aChainSlug));

        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _deployContractsOnSingleChain(
            _a,
            remoteChainSlug,
            isExecutionOpen,
            transmitterPrivateKeys
        );

        optimisticSwitchboard = OptimisticSwitchboard(
            address(_a.configs__[1].switchboard__)
        );

        packetId = _packMessageId(remoteChainSlug, address(uint160(c++)), 0);
    }

    function testIsAllowed() external {
        uint256 proposeTime = block.timestamp -
            optimisticSwitchboard.timeoutInSeconds();

        bool isAllowed = optimisticSwitchboard.allowPacket(
            0,
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
        optimisticSwitchboard.grantRoleWithSlug(
            WATCHER_ROLE,
            srcChainSlug,
            _socketOwner
        );

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_PATH_SIG_IDENTIFIER,
                address(optimisticSwitchboard),
                _a.chainSlug,
                srcChainSlug,
                nonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit PathTripped(srcChainSlug, true);
        optimisticSwitchboard.tripPath(nonce++, srcChainSlug, sig);

        bool isAllowed = optimisticSwitchboard.allowPacket(
            0,
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

        optimisticSwitchboard.grantRoleWithSlug(
            WATCHER_ROLE,
            remoteChainSlug,
            watcher2
        );
        vm.stopPrank();
    }

    function testRevokeWatcherRole() external {
        vm.startPrank(_socketOwner);

        optimisticSwitchboard.grantRoleWithSlug(
            WATCHER_ROLE,
            remoteChainSlug,
            vm.addr(_altWatcherPrivateKey)
        );
        vm.stopPrank();
    }

    function testregisterSiblingSlug() public {
        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        optimisticSwitchboard.registerSiblingSlug(
            _b.chainSlug,
            1,
            1,
            0,
            siblingSwitchboard
        );

        vm.startPrank(_socketOwner);
        optimisticSwitchboard.registerSiblingSlug(
            _b.chainSlug,
            1,
            1,
            1,
            siblingSwitchboard
        );

        vm.expectRevert(SwitchboardExists.selector);
        optimisticSwitchboard.registerSiblingSlug(
            _b.chainSlug,
            1,
            1,
            1,
            siblingSwitchboard
        );

        assertEq(optimisticSwitchboard.initialPacketCount(_b.chainSlug), 1);

        vm.stopPrank();
    }

    function testSetFees() external {
        uint128 switchboardFee = 1000;
        uint128 verificationFee = 1000;
        uint256 feeNonce = optimisticSwitchboard.nextNonce(_socketOwner);

        (uint256 sbFee, uint256 vFee) = optimisticSwitchboard.fees(
            remoteChainSlug
        );

        assertEq(sbFee, 0);
        assertEq(vFee, 0);

        bytes32 digest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(optimisticSwitchboard),
                _a.chainSlug,
                remoteChainSlug,
                feeNonce,
                switchboardFee,
                verificationFee
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        hoax(_socketOwner);
        optimisticSwitchboard.grantRoleWithSlug(
            FEES_UPDATER_ROLE,
            remoteChainSlug,
            _socketOwner
        );

        optimisticSwitchboard.setFees(
            feeNonce,
            remoteChainSlug,
            switchboardFee,
            verificationFee,
            sig
        );

        vm.expectRevert(SwitchboardBase.InvalidNonce.selector);
        optimisticSwitchboard.setFees(
            feeNonce,
            remoteChainSlug,
            switchboardFee,
            verificationFee,
            sig
        );
    }
}
