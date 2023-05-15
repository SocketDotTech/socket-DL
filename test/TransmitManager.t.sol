// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract TransmitManagerTest is Setup {
    GasPriceOracle internal gasPriceOracle;

    address public constant NATIVE_TOKEN_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    uint32 chainSlug = uint32(uint256(0x2013AA263));
    uint32 destChainSlug = uint32(uint256(0x2013AA264));
    uint32 chainSlug2 = uint32(uint256(0x2113AA263));

    uint256 immutable ownerPrivateKey = c++;
    address owner;

    uint256 immutable transmitterPrivateKey = c++;
    address transmitter;

    uint256 immutable nonTransmitterPrivateKey = c++;
    address nonTransmitter;

    uint256 immutable feesPayerPrivateKey = c++;
    address feesPayer;

    uint256 immutable feesWithdrawerPrivateKey = c++;
    address feesWithdrawer;

    uint256 sealGasLimit = 200000;
    uint256 proposeGasLimit = 100000;
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;

    uint256 ownerNonce;

    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event SealGasLimitSet(uint256 gasLimit_);
    event ProposeGasLimitSet(uint32 dstChainSlug_, uint256 gasLimit_);
    event TransmitManagerUpdated(address transmitManager);
    error TransmitterNotFound();
    error InsufficientTransmitFees();
    event FeesWithdrawn(address account_, uint256 value_);
    event SignatureVerifierSet(address signatureVerifier_);

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        transmitter = vm.addr(transmitterPrivateKey);
        nonTransmitter = vm.addr(nonTransmitterPrivateKey);
        feesPayer = vm.addr(feesPayerPrivateKey);
        feesWithdrawer = vm.addr(feesWithdrawerPrivateKey);

        gasPriceOracle = new GasPriceOracle(owner, chainSlug);
        signatureVerifier = new SignatureVerifier();
        transmitManager = new TransmitManager(
            signatureVerifier,
            gasPriceOracle,
            owner,
            chainSlug,
            sealGasLimit
        );

        vm.startPrank(owner);
        gasPriceOracle.grantRole(GOVERNANCE_ROLE, owner);
        gasPriceOracle.grantRole(GAS_LIMIT_UPDATER_ROLE, owner);
        gasPriceOracle.setTransmitManager(transmitManager);
        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            chainSlug,
            transmitter
        );
        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            destChainSlug,
            transmitter
        );
        transmitManager.grantRole(GAS_LIMIT_UPDATER_ROLE, owner);
        transmitManager.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            destChainSlug,
            owner
        );

        //grant FeesUpdater Role
        transmitManager.grantRole(FEES_UPDATER_ROLE, owner);
        transmitManager.grantRoleWithSlug(
            FEES_UPDATER_ROLE,
            destChainSlug,
            owner
        );

        transmitManager.grantRole(RESCUE_ROLE, owner);
        transmitManager.grantRole(WITHDRAW_ROLE, owner);
        transmitManager.grantRole(GOVERNANCE_ROLE, owner);
        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                SEAL_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                chainSlug,
                ownerNonce,
                sealGasLimit
            )
        );
        bytes memory sig = _createSignature(digest, ownerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit SealGasLimitSet(sealGasLimit);
        transmitManager.setSealGasLimit(ownerNonce++, sealGasLimit, sig);

        digest = keccak256(
            abi.encode(
                PROPOSE_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                chainSlug,
                destChainSlug,
                ownerNonce,
                proposeGasLimit
            )
        );
        sig = _createSignature(digest, ownerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit ProposeGasLimitSet(destChainSlug, proposeGasLimit);
        transmitManager.setProposeGasLimit(
            ownerNonce++,
            destChainSlug,
            proposeGasLimit,
            sig
        );

        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                chainSlug,
                destChainSlug,
                ownerNonce,
                _transmissionFees
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            ownerPrivateKey
        );

        transmitManager.setTransmissionFees(
            ownerNonce++,
            uint32(destChainSlug),
            _transmissionFees,
            feesUpdateSignature
        );

        digest = keccak256(
            abi.encode(chainSlug, gasPriceOracleNonce, sourceGasPrice)
        );
        sig = _createSignature(digest, transmitterPrivateKey);

        gasPriceOracle.setSourceGasPrice(
            gasPriceOracleNonce++,
            sourceGasPrice,
            sig
        );

        digest = keccak256(
            abi.encode(
                chainSlug,
                destChainSlug,
                gasPriceOracleNonce,
                relativeGasPrice
            )
        );

        sig = _createSignature(digest, transmitterPrivateKey);

        gasPriceOracle.setRelativeGasPrice(
            destChainSlug,
            gasPriceOracleNonce++,
            relativeGasPrice,
            sig
        );
    }

    function testGenerateAndVerifySignature() public {
        bytes32 packetId = bytes32("");
        bytes32 root = bytes32(abi.encode(123));
        bytes32 digest = keccak256(abi.encode(chainSlug, packetId, root));
        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

        address transmitterDecoded = signatureVerifier.recoverSigner(
            chainSlug,
            packetId,
            root,
            sig
        );

        assertEq(transmitter, transmitterDecoded);
    }

    function testCheckTransmitter() public {
        uint256 packetId = 123;
        bytes32 root = bytes32(abi.encode(123));
        bytes32 digest = keccak256(abi.encode(chainSlug, packetId, root));

        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

        (address transmitter_Rsp, bool isTransmitter) = transmitManager
            .checkTransmitter(
                chainSlug,
                keccak256(abi.encode(chainSlug, packetId, root)),
                sig
            );
        assertEq(transmitter_Rsp, transmitter);
        assertTrue(isTransmitter);
    }

    function testGetMinFees() public {
        uint256 minFees = transmitManager.getMinFees(destChainSlug);

        // sealGasLimit * sourceGasPrice + proposeGasLimit * relativeGasPrice
        uint256 minFees_Expected = sealGasLimit *
            sourceGasPrice +
            proposeGasLimit *
            relativeGasPrice;

        assertEq(minFees, minFees_Expected);
    }

    function testPayFees() public {
        uint256 minFees = transmitManager.getMinFees(destChainSlug);
        deal(feesPayer, minFees);

        hoax(feesPayer);
        transmitManager.payFees{value: minFees}(destChainSlug);

        assertEq(address(transmitManager).balance, minFees);
    }

    function testWithdrawFees() public {
        uint256 minFees = transmitManager.getMinFees(destChainSlug);
        deal(feesPayer, minFees);

        vm.startPrank(feesPayer);
        transmitManager.payFees{value: minFees}(destChainSlug);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(false, false, false, true);
        emit FeesWithdrawn(feesWithdrawer, minFees);
        transmitManager.withdrawFees(feesWithdrawer);
        vm.stopPrank();

        assertEq(feesWithdrawer.balance, minFees);
    }

    function testWithdrawFeesToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert();
        transmitManager.withdrawFees(address(0));
        vm.stopPrank();
    }

    function testGrantTransmitterRole() public {
        assertFalse(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                chainSlug2,
                nonTransmitter
            )
        );

        vm.startPrank(owner);
        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            chainSlug2,
            nonTransmitter
        );
        vm.stopPrank();

        assertTrue(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                chainSlug2,
                nonTransmitter
            )
        );
    }

    function testRevokeTransmitterRole() public {
        assertFalse(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                chainSlug2,
                nonTransmitter
            )
        );

        vm.startPrank(owner);
        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            chainSlug2,
            nonTransmitter
        );
        vm.stopPrank();

        assertTrue(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                chainSlug2,
                nonTransmitter
            )
        );

        vm.startPrank(owner);
        transmitManager.revokeRoleWithSlug(
            TRANSMITTER_ROLE,
            chainSlug2,
            nonTransmitter
        );
        vm.stopPrank();

        assertFalse(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                chainSlug2,
                nonTransmitter
            )
        );
    }

    function testSetSignatureVerifier() public {
        SignatureVerifier signatureVerifierNew = new SignatureVerifier();

        hoax(owner);
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

        assertEq(address(transmitManager).balance, 0);
        deal(address(transmitManager), amount);
        assertEq(address(transmitManager).balance, amount);

        hoax(owner);

        transmitManager.rescueFunds(
            NATIVE_TOKEN_ADDRESS,
            feesWithdrawer,
            amount
        );

        assertEq(feesWithdrawer.balance, amount);
        assertEq(address(transmitManager).balance, 0);
    }
}
