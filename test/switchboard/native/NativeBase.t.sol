// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

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

    OptimismSwitchboard optimismSwitchboard;
    ICapacitor singleCapacitor;

    event SwitchboardTripped(bool tripGlobalFuse_);
    event SwitchboardFeesSet(uint256 switchboardFees, uint256 verificationFees);

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(uint256(420));
        _b.chainSlug = uint32(uint256(5));

        // taking optimism switchboard to test base
        uint256 fork = vm.createFork(
            vm.envString("OPTIMISM_GOERLI_RPC"),
            5911043
        );
        vm.selectFork(fork);

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPivateKeys);
    }

    function testRegisterSiblingSlug() public {
        assertFalse(optimismSwitchboard.isInitialised());

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        optimismSwitchboard.registerSiblingSlug(_b.chainSlug, 1, 1);

        vm.startPrank(_socketOwner);
        optimismSwitchboard.registerSiblingSlug(_b.chainSlug, 1, 1);

        vm.expectRevert(NativeSwitchboardBase.AlreadyInitialised.selector);
        optimismSwitchboard.registerSiblingSlug(_b.chainSlug, 1, 1);

        assertTrue(optimismSwitchboard.isInitialised());
        assertEq(optimismSwitchboard.maxPacketLength(), 1);

        vm.stopPrank();
    }

    function testUpdateRemoteNativeSwitchboard() public {
        address newRemoteNativeSwitchboard = address(uint160(c++));
        assertEq(
            address(optimismSwitchboard.remoteNativeSwitchboard()),
            remoteNativeSwitchboard_
        );

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        optimismSwitchboard.updateRemoteNativeSwitchboard(
            newRemoteNativeSwitchboard
        );

        hoax(_socketOwner);
        optimismSwitchboard.updateRemoteNativeSwitchboard(
            newRemoteNativeSwitchboard
        );

        assertEq(
            address(optimismSwitchboard.remoteNativeSwitchboard()),
            newRemoteNativeSwitchboard
        );
    }

    function testWithdrawFees() public {
        (uint256 minFees, ) = optimismSwitchboard.getMinFees(bChainSlug);
        deal(_feesPayer, minFees);

        assertEq(address(optimismSwitchboard).balance, 0);
        assertEq(_feesPayer.balance, minFees);

        vm.startPrank(_feesPayer);
        optimismSwitchboard.payFees{value: minFees}(bChainSlug);
        vm.stopPrank();

        assertEq(_feesWithdrawer.balance, 0);

        hoax(_raju);
        vm.expectRevert();
        optimismSwitchboard.withdrawFees(_feesWithdrawer);

        hoax(_socketOwner);
        optimismSwitchboard.withdrawFees(_feesWithdrawer);

        assertEq(_feesWithdrawer.balance, minFees);
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;

        hoax(_socketOwner);
        vm.expectRevert();
        optimismSwitchboard.rescueFunds(
            NATIVE_TOKEN_ADDRESS,
            address(0),
            amount
        );

        hoax(_socketOwner);
        _rescueNative(
            address(optimismSwitchboard),
            NATIVE_TOKEN_ADDRESS,
            _feesWithdrawer,
            amount
        );
    }

    function testTripGlobal() external {
        uint256 tripNonce = optimismSwitchboard.nextNonce(_socketOwner);
        assertFalse(optimismSwitchboard.tripGlobalFuse());

        vm.startPrank(_socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_NATIVE_SIG_IDENTIFIER,
                address(optimismSwitchboard),
                _a.chainSlug,
                tripNonce,
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         AccessControl.NoPermit.selector,
        //         TRIP_ROLE
        //     )
        // );
        // optimismSwitchboard.tripGlobal(
        //     tripNonce,
        //     sig
        // );

        optimismSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(true);
        optimismSwitchboard.tripGlobal(tripNonce, sig);
        vm.stopPrank();

        assertTrue(optimismSwitchboard.tripGlobalFuse());

        vm.expectRevert(NativeSwitchboardBase.InvalidNonce.selector);
        optimismSwitchboard.tripGlobal(tripNonce, sig);
    }

    function testUntrip() external {
        vm.startPrank(_socketOwner);
        optimismSwitchboard.grantRole(TRIP_ROLE, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                TRIP_NATIVE_SIG_IDENTIFIER,
                address(optimismSwitchboard),
                _a.chainSlug,
                optimismSwitchboard.nextNonce(_socketOwner),
                true
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        optimismSwitchboard.tripGlobal(
            optimismSwitchboard.nextNonce(_socketOwner),
            sig
        );
        assertTrue(optimismSwitchboard.tripGlobalFuse());

        // untrip
        uint256 untripNonce = optimismSwitchboard.nextNonce(_socketOwner);
        digest = keccak256(
            abi.encode(
                UNTRIP_NATIVE_SIG_IDENTIFIER,
                address(optimismSwitchboard),
                _a.chainSlug,
                untripNonce,
                false
            )
        );
        sig = _createSignature(digest, _socketOwnerPrivateKey);

        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         AccessControl.NoPermit.selector,
        //         UNTRIP_ROLE
        //     )
        // );
        // optimismSwitchboard.untrip(
        //     untripNonce,
        //     sig
        // );

        optimismSwitchboard.grantRole(UNTRIP_ROLE, _socketOwner);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardTripped(false);
        optimismSwitchboard.untrip(untripNonce, sig);

        vm.stopPrank();

        assertFalse(optimismSwitchboard.tripGlobalFuse());

        vm.expectRevert(NativeSwitchboardBase.InvalidNonce.selector);
        optimismSwitchboard.untrip(untripNonce, sig);
    }

    function testSetFees() external {
        uint256 switchboardFee = 1000;
        uint256 verificationFee = 1000;
        uint256 feeNonce = optimismSwitchboard.nextNonce(_feesWithdrawer);
        assertEq(optimismSwitchboard.switchboardFees(), 0);
        assertEq(optimismSwitchboard.verificationFees(), 0);

        bytes32 digest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(optimismSwitchboard),
                _a.chainSlug,
                feeNonce,
                switchboardFee,
                verificationFee
            )
        );
        bytes memory sig = _createSignature(digest, _feesWithdrawerPrivateKey);

        hoax(_socketOwner);
        optimismSwitchboard.grantRole(FEES_UPDATER_ROLE, _feesWithdrawer);

        vm.expectEmit(false, false, false, true);
        emit SwitchboardFeesSet(switchboardFee, verificationFee);
        optimismSwitchboard.setFees(
            feeNonce,
            _b.chainSlug,
            switchboardFee,
            verificationFee,
            sig
        );

        vm.expectRevert(NativeSwitchboardBase.InvalidNonce.selector);
        optimismSwitchboard.setFees(
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

        addOptimismSwitchboard(_a, _b.chainSlug, _capacitorType);
    }

    function addOptimismSwitchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory) {
        vm.startPrank(_socketOwner);

        optimismSwitchboard = new OptimismSwitchboard(
            cc_.chainSlug,
            receiveGasLimit_,
            _socketOwner,
            address(cc_.socket__),
            crossDomainManagerAddress_,
            cc_.sigVerifier__
        );

        optimismSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        optimismSwitchboard.grantRole(WITHDRAW_ROLE, _socketOwner);
        optimismSwitchboard.grantRole(RESCUE_ROLE, _socketOwner);

        vm.stopPrank();

        hoax(_socketOwner);
        optimismSwitchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
    }
}
