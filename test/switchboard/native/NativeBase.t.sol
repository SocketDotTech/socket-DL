// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/OptimismSwitchboard.sol";

contract NativeBaseSwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 receiveGasLimit_ = 100000;
    address remoteNativeSwitchboard_ =
        0x793753781B45565C68392c4BB556C1bEcFC42F24;
    address crossDomainManagerAddress_ =
        0x4200000000000000000000000000000000000007;

    OptimismSwitchboard nativeSwitchboard;
    ICapacitor singleCapacitor;

    event GlobalTripChanged(bool isGlobalTipped_);
    event SwitchboardFeesSet(
        uint256 switchboardFees,
        uint256 verificationOverheadFees
    );

    function setUp() external {
        initialize();

        _a.chainSlug = uint32(uint256(420));
        _b.chainSlug = uint32(uint256(5));

        // taking optimism switchboard to test base
        uint256 fork = vm.createFork(
            vm.envString("OPTIMISM_GOERLI_RPC"),
            5911043
        );
        vm.selectFork(fork);

        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPrivateKeys);
    }

    function testRegisterSiblingSlug() public {
        assertFalse(nativeSwitchboard.isInitialized());

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        nativeSwitchboard.registerSiblingSlug(
            _b.chainSlug,
            1,
            1,
            0,
            remoteNativeSwitchboard_
        );

        vm.startPrank(_socketOwner);
        nativeSwitchboard.registerSiblingSlug(
            _b.chainSlug,
            1,
            1,
            0,
            remoteNativeSwitchboard_
        );

        vm.expectRevert(NativeSwitchboardBase.AlreadyInitialized.selector);
        nativeSwitchboard.registerSiblingSlug(
            _b.chainSlug,
            1,
            1,
            0,
            remoteNativeSwitchboard_
        );

        assertTrue(nativeSwitchboard.isInitialized());
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        uint256 amount = 1e18;

        vm.startPrank(_socketOwner);
        nativeSwitchboard.grantRole(WITHDRAW_ROLE, _socketOwner);
        vm.deal(address(nativeSwitchboard), amount);
        uint256 initialBal = _fundRescuer.balance;

        vm.expectRevert(ZeroAddress.selector);
        nativeSwitchboard.withdrawFees(address(0));

        nativeSwitchboard.withdrawFees(_fundRescuer);

        assertEq(address(nativeSwitchboard).balance, 0);
        assertEq(_fundRescuer.balance, initialBal + amount);

        vm.stopPrank();
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;

        hoax(_socketOwner);
        vm.expectRevert();
        nativeSwitchboard.rescueFunds(NATIVE_TOKEN_ADDRESS, address(0), amount);

        hoax(_socketOwner);
        _rescueNative(
            address(nativeSwitchboard),
            NATIVE_TOKEN_ADDRESS,
            _feesWithdrawer,
            amount
        );
    }

    // should return false if packet not received from native bridge (default case)
    function testAllowPacket() external {
        bytes32 packetId = bytes32("RANDOM_PACKET");
        bytes32 root = bytes32("RANDOM_ROOT");

        assertFalse(
            nativeSwitchboard.allowPacket(
                packetId,
                root,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );
    }

    function testTripGlobal() external {
        uint256 tripNonce = nativeSwitchboard.nextNonce(_socketOwner);
        assertFalse(nativeSwitchboard.isGlobalTipped());

        vm.startPrank(_socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_NATIVE_SIG_IDENTIFIER,
                address(nativeSwitchboard),
                _a.chainSlug,
                tripNonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectRevert(
            abi.encodeWithSelector(AccessControl.NoPermit.selector, TRIP_ROLE)
        );
        nativeSwitchboard.tripGlobal(tripNonce, sig);

        nativeSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit GlobalTripChanged(true);
        nativeSwitchboard.tripGlobal(tripNonce, sig);
        vm.stopPrank();

        assertTrue(nativeSwitchboard.isGlobalTipped());

        bytes32 packetId = bytes32("RANDOM_PACKET");
        bytes32 root = bytes32("RANDOM_ROOT");

        assertFalse(
            nativeSwitchboard.allowPacket(
                packetId,
                root,
                uint256(0),
                uint32(0),
                uint256(0)
            )
        );

        vm.expectRevert(NativeSwitchboardBase.InvalidNonce.selector);
        nativeSwitchboard.tripGlobal(tripNonce, sig);
    }

    function testUntrip() external {
        vm.startPrank(_socketOwner);
        nativeSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_NATIVE_SIG_IDENTIFIER,
                address(nativeSwitchboard),
                _a.chainSlug,
                nativeSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        nativeSwitchboard.tripGlobal(
            nativeSwitchboard.nextNonce(_socketOwner),
            sig
        );
        assertTrue(nativeSwitchboard.isGlobalTipped());

        // unTrip
        uint256 unTripNonce = nativeSwitchboard.nextNonce(_socketOwner);
        digest = keccak256(
            abi.encode(
                UN_TRIP_NATIVE_SIG_IDENTIFIER,
                address(nativeSwitchboard),
                _a.chainSlug,
                unTripNonce,
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
        nativeSwitchboard.unTrip(unTripNonce, sig);

        nativeSwitchboard.grantRole(UN_TRIP_ROLE, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit GlobalTripChanged(false);
        nativeSwitchboard.unTrip(unTripNonce, sig);

        vm.stopPrank();

        assertFalse(nativeSwitchboard.isGlobalTipped());

        vm.expectRevert(NativeSwitchboardBase.InvalidNonce.selector);
        nativeSwitchboard.unTrip(unTripNonce, sig);
    }

    function testSetFees() external {
        uint128 switchboardFee = 1000;
        uint128 verificationFee = 1000;
        uint256 feeNonce = nativeSwitchboard.nextNonce(_socketOwner);
        assertEq(nativeSwitchboard.switchboardFees(), 0);
        assertEq(nativeSwitchboard.verificationOverheadFees(), 0);

        bytes32 digest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(nativeSwitchboard),
                _a.chainSlug,
                feeNonce,
                switchboardFee,
                verificationFee
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardFeesSet(switchboardFee, verificationFee);
        nativeSwitchboard.setFees(
            feeNonce,
            _b.chainSlug,
            switchboardFee,
            verificationFee,
            sig
        );

        vm.expectRevert(NativeSwitchboardBase.InvalidNonce.selector);
        nativeSwitchboard.setFees(
            feeNonce,
            _b.chainSlug,
            switchboardFee,
            verificationFee,
            sig
        );
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );

        addOptimismSwitchboard(_a);
    }

    function addOptimismSwitchboard(ChainContext storage cc_) internal {
        vm.startPrank(_socketOwner);

        nativeSwitchboard = new OptimismSwitchboard(
            cc_.chainSlug,
            receiveGasLimit_,
            _socketOwner,
            address(cc_.socket__),
            crossDomainManagerAddress_,
            cc_.sigVerifier__
        );

        nativeSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        nativeSwitchboard.grantRole(WITHDRAW_ROLE, _feesWithdrawer);
        nativeSwitchboard.grantRole(RESCUE_ROLE, _socketOwner);
        nativeSwitchboard.grantRole(FEES_UPDATER_ROLE, _socketOwner);

        vm.stopPrank();
    }
}
