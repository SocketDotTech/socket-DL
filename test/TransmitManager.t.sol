// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vm} from "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/GasPriceOracle.sol";
import {TransmitManager} from "../contracts/TransmitManager.sol";
import {SignatureVerifier} from "../contracts/utils/SignatureVerifier.sol";

contract TransmitManagerTest is Test {
    GasPriceOracle internal gasPriceOracle;

    uint256 chainSlug = uint32(uint256(0x2013AA263));
    uint256 destChainSlug = uint32(uint256(0x2013AA264));
    uint256 chainSlug2 = uint32(uint256(0x2113AA263));

    uint256 internal c = 1;

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

    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event SealGasLimitSet(uint256 gasLimit_);
    event ProposeGasLimitSet(uint256 dstChainSlug_, uint256 gasLimit_);
    event TransmitManagerUpdated(address transmitManager);
    error TransmitterNotFound();
    error InsufficientTransmitFees();
    event FeesWithdrawn(address account_, uint256 value_);

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
        gasPriceOracle.setTransmitManager(transmitManager);
        transmitManager.grantTransmitterRole(chainSlug, transmitter);
        transmitManager.grantTransmitterRole(destChainSlug, transmitter);

        vm.expectEmit(false, false, false, true);
        emit SealGasLimitSet(sealGasLimit);
        transmitManager.setSealGasLimit(sealGasLimit);

        vm.expectEmit(false, false, false, true);
        emit ProposeGasLimitSet(destChainSlug, proposeGasLimit);
        transmitManager.setProposeGasLimit(destChainSlug, proposeGasLimit);

        vm.stopPrank();

        vm.startPrank(transmitter);
        gasPriceOracle.setSourceGasPrice(sourceGasPrice);
        gasPriceOracle.setRelativeGasPrice(destChainSlug, relativeGasPrice);

        vm.stopPrank();
    }

    function testGenerateAndVerifySignature() public {
        uint256 packetId = 123;
        bytes32 root = bytes32(abi.encode(123));
        bytes32 digest = keccak256(abi.encode(chainSlug, packetId, root));
        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

        address transmitter_Decoded = signatureVerifier.recoverSigner(
            chainSlug,
            packetId,
            root,
            sig
        );

        assertEq(transmitter, transmitter_Decoded);
    }

    function testCheckTransmitter() public {
        uint256 packetId = 123;
        bytes32 root = bytes32(abi.encode(123));
        bytes32 digest = keccak256(abi.encode(chainSlug, packetId, root));
        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

        (address transmitter_Rsp, bool isTransmitter) = transmitManager
            .checkTransmitter(
                (chainSlug << 128) | chainSlug,
                packetId,
                root,
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

    function testPayInsufficientFees() public {
        uint256 minFees = transmitManager.getMinFees(destChainSlug);
        deal(feesPayer, minFees);

        vm.startPrank(feesPayer);
        vm.expectRevert(InsufficientTransmitFees.selector);
        transmitManager.payFees{value: minFees - 1e4}(destChainSlug);
        vm.stopPrank();
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
        assertFalse(transmitManager.isTransmitter(nonTransmitter, chainSlug2));

        vm.startPrank(owner);
        transmitManager.grantTransmitterRole(chainSlug2, nonTransmitter);
        vm.stopPrank();

        assertTrue(transmitManager.isTransmitter(nonTransmitter, chainSlug2));
    }

    function testRevokeTransmitterRole() public {
        assertFalse(transmitManager.isTransmitter(nonTransmitter, chainSlug2));

        vm.startPrank(owner);
        transmitManager.grantTransmitterRole(chainSlug2, nonTransmitter);
        vm.stopPrank();

        assertTrue(transmitManager.isTransmitter(nonTransmitter, chainSlug2));

        vm.startPrank(owner);
        transmitManager.revokeTransmitterRole(chainSlug2, nonTransmitter);
        vm.stopPrank();

        assertFalse(transmitManager.isTransmitter(nonTransmitter, chainSlug2));
    }

    function _createSignature(
        bytes32 digest_,
        uint256 privateKey_
    ) internal returns (bytes memory sig) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_)
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(privateKey_, digest);
        sig = new bytes(65);
        bytes1 v32 = bytes1(sigV);

        assembly {
            mstore(add(sig, 96), v32)
            mstore(add(sig, 32), sigR)
            mstore(add(sig, 64), sigS)
        }
    }
}
