// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";

contract TransmitManagerTest is Setup {
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    error TransmitterNotFound();
    error InsufficientTransmitFees();

    event TransmitManagerUpdated(address transmitManager);
    event FeesWithdrawn(address account_, uint256 value_);
    event SignatureVerifierSet(address signatureVerifier_);
    event TransmissionFeesSet(uint256 dstChainSlug, uint256 transmissionFees);

    function setUp() public {
        initialize();
        _a.chainSlug = uint32(uint256(aChainSlug));
        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _deployContractsOnSingleChain(
            _a,
            bChainSlug,
            isExecutionOpen,
            transmitterPrivateKeys
        );
        signatureVerifier = _a.sigVerifier__;
        transmitManager = _a.transmitManager__;
    }

    function testCheckTransmitter() public {
        uint256 packetId = 123;
        bytes32 root = bytes32(abi.encode(123));
        bytes32 digest = keccak256(abi.encode(aChainSlug, packetId, root));

        bytes memory sig = _createSignature(digest, _transmitterPrivateKey);

        (address _transmitter_Rsp, bool isTransmitter) = transmitManager
            .checkTransmitter(
                aChainSlug,
                keccak256(abi.encode(aChainSlug, packetId, root)),
                sig
            );
        assertEq(_transmitter_Rsp, _transmitter);
        assertTrue(isTransmitter);
    }

    function testWithdrawFees() public {
        uint256 amount = 1e18;

        vm.startPrank(_socketOwner);
        vm.deal(address(transmitManager), amount);
        uint256 initialBal = _fundRescuer.balance;

        vm.expectRevert(ZeroAddress.selector);
        transmitManager.withdrawFees(address(0));

        transmitManager.withdrawFees(_fundRescuer);

        assertEq(address(transmitManager).balance, 0);
        assertEq(_fundRescuer.balance, initialBal + amount);

        vm.stopPrank();
    }

    function testGrantTransmitterRole() public {
        assertFalse(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                cChainSlug,
                _nonTransmitter
            )
        );

        vm.startPrank(_socketOwner);
        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            cChainSlug,
            _nonTransmitter
        );
        vm.stopPrank();

        assertTrue(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                cChainSlug,
                _nonTransmitter
            )
        );
    }

    function testRevokeTransmitterRole() public {
        assertFalse(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                cChainSlug,
                _nonTransmitter
            )
        );

        vm.startPrank(_socketOwner);
        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            cChainSlug,
            _nonTransmitter
        );
        vm.stopPrank();

        assertTrue(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                cChainSlug,
                _nonTransmitter
            )
        );

        vm.startPrank(_socketOwner);
        transmitManager.revokeRoleWithSlug(
            TRANSMITTER_ROLE,
            cChainSlug,
            _nonTransmitter
        );
        vm.stopPrank();

        assertFalse(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                cChainSlug,
                _nonTransmitter
            )
        );
    }

    function testSetSignatureVerifier() public {
        SignatureVerifier signatureVerifierNew = new SignatureVerifier(
            _socketOwner
        );

        hoax(_socketOwner);
        vm.expectEmit(false, false, false, true);
        emit SignatureVerifierSet(address(signatureVerifierNew));
        transmitManager.setSignatureVerifier(address(signatureVerifierNew));

        assertEq(
            address(transmitManager.signatureVerifier__()),
            address(signatureVerifierNew)
        );
    }

    function testSetTransmissionFees() public {
        uint128 newTransmissionFees = _transmissionFees * 2;

        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(transmitManager),
                _a.chainSlug,
                bChainSlug,
                _a.transmitterNonce,
                newTransmissionFees
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        ExecutionManager em = ExecutionManager(
            address(_a.socket__.executionManager__())
        );

        assertEq(
            em.transmissionMinFees(address(transmitManager), bChainSlug),
            _transmissionFees
        );

        vm.expectEmit(true, true, false, false);
        emit TransmissionFeesSet(bChainSlug, newTransmissionFees);
        transmitManager.setTransmissionFees(
            _a.transmitterNonce++,
            bChainSlug,
            newTransmissionFees,
            feesUpdateSignature
        );

        assertEq(
            em.transmissionMinFees(address(transmitManager), bChainSlug),
            newTransmissionFees
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                keccak256(abi.encode(FEES_UPDATER_ROLE, cChainSlug))
            )
        );
        transmitManager.setTransmissionFees(
            _a.transmitterNonce++,
            cChainSlug,
            newTransmissionFees,
            feesUpdateSignature
        );
    }

    function testSetTransmissionFeesForInvalidNonce() public {
        uint128 newTransmissionFees = _transmissionFees * 2;
        uint256 wrongNonce = _a.transmitterNonce + 1;

        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(transmitManager),
                _a.chainSlug,
                bChainSlug,
                wrongNonce,
                newTransmissionFees
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            _socketOwnerPrivateKey
        );

        vm.expectRevert(TransmitManager.InvalidNonce.selector);
        transmitManager.setTransmissionFees(
            wrongNonce,
            bChainSlug,
            newTransmissionFees,
            feesUpdateSignature
        );
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;
        hoax(_socketOwner);
        _rescueNative(
            address(transmitManager),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
    }
}
