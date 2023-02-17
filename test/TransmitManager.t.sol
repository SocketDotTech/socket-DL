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

    uint256 internal c = 1;

    uint256 immutable ownerPrivateKey = c++;
    address owner;

    uint256 immutable transmitterPrivateKey = c++;
    address transmitter;

    uint256 immutable nonTransmitterPrivateKey = c++;
    address nonTransmitter;

    uint256 sealGasLimit = 200000;
    uint256 proposeGasLimit = 100000;
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;

    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event GasPriceUpdated(uint256 dstChainSlug_, uint256 relativeGasPrice_);
    event TransmitManagerUpdated(address transmitManager);
    event SourceGasPriceUpdated(uint256 sourceGasPrice);
    error TransmitterNotFound();

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        transmitter = vm.addr(transmitterPrivateKey);
        nonTransmitter = vm.addr(nonTransmitterPrivateKey);

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
        transmitManager.setProposeGasLimit(destChainSlug, proposeGasLimit);
        vm.stopPrank();

        vm.startPrank(transmitter);
        gasPriceOracle.setSourceGasPrice(sourceGasPrice);
        gasPriceOracle.setRelativeGasPrice(destChainSlug, relativeGasPrice);

        vm.stopPrank();
    }

    function testGrantTransmitterRole() public {
        vm.startPrank(owner);
        transmitManager.grantTransmitterRole(chainSlug, transmitter);
        vm.stopPrank();

        assertTrue(transmitManager.isTransmitter(transmitter, chainSlug));
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
