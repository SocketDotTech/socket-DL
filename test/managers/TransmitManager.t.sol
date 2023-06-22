// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";

contract TransmitManagerTest is Setup {
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    error TransmitterNotFound();
    error InsufficientTransmitFees();

    event TransmitManagerUpdated(address transmitManager);
    event FeesWithdrawn(address account_, uint256 value_);
    event SignatureVerifierSet(address signatureVerifier_);

    function setUp() public {
        initialise();
        _a.chainSlug = uint32(uint256(aChainSlug));
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _deployContractsOnSingleChain(
            _a,
            bChainSlug,
            isExecutionOpen,
            transmitterPivateKeys
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

    // function testWithdrawFees() public {
    //     uint256 minFees = 0;
    //     // transmitManager.getMinFees(bChainSlug);
    //     deal(_feesPayer, minFees);

    //     vm.startPrank(_feesPayer);
    //     transmitManager.payFees{value: minFees}(bChainSlug);
    //     vm.stopPrank();

    //     vm.startPrank(_socketOwner);
    //     vm.expectEmit(false, false, false, true);
    //     emit FeesWithdrawn(_feesWithdrawer, minFees);
    //     transmitManager.withdrawFees(_feesWithdrawer);
    //     vm.stopPrank();

    //     assertEq(_feesWithdrawer.balance, minFees);
    // }

    function testWithdrawFeesToZeroAddress() public {
        vm.startPrank(_socketOwner);

        vm.expectRevert();
        transmitManager.withdrawFees(address(0));
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
