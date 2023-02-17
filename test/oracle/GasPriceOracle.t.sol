// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import "../../lib/forge-std/src/console.sol";
import "../../contracts/GasPriceOracle.sol";
import {TransmitManager} from "../../contracts/TransmitManager.sol";
import {SignatureVerifier} from "../../contracts/utils/SignatureVerifier.sol";

contract GasPriceOracleTest is Test {
    GasPriceOracle internal gasPriceOracle;
    uint256 chainSlug = uint32(uint256(0x2013AA263));
    uint256 destChainSlug = uint32(uint256(0x2013AA264));
    uint256 internal c = 1;
    address immutable owner = address(uint160(c++));
    address immutable transmitter = address(uint160(c++));
    address immutable nonTransmitter = address(uint160(c++));
    uint256 gasLimit = 200000;
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event GasPriceUpdated(uint256 dstChainSlug_, uint256 relativeGasPrice_);
    event TransmitManagerUpdated(address transmitManager);
    event SourceGasPriceUpdated(uint256 sourceGasPrice);
    error TransmitterNotFound();

    function setUp() public {
        gasPriceOracle = new GasPriceOracle(owner, chainSlug);
        signatureVerifier = new SignatureVerifier();
        transmitManager = new TransmitManager(
            signatureVerifier,
            gasPriceOracle,
            owner,
            chainSlug,
            gasLimit
        );
        vm.startPrank(owner);
        transmitManager.grantTransmitterRole(chainSlug, transmitter);
        transmitManager.grantTransmitterRole(destChainSlug, transmitter);

        vm.expectEmit(false, false, false, true);
        emit TransmitManagerUpdated(address(transmitManager));
        gasPriceOracle.setTransmitManager(transmitManager);

        vm.stopPrank();
    }

    function testSetSourceGasPrice() public {
        vm.startPrank(transmitter);

        uint256 sourceGasPrice = 1200000;

        vm.expectEmit(false, false, false, true);
        emit SourceGasPriceUpdated(sourceGasPrice);

        gasPriceOracle.setSourceGasPrice(sourceGasPrice);

        vm.stopPrank();

        assert(gasPriceOracle.sourceGasPrice() == sourceGasPrice);
    }

    function testSetRelativeGasPrice() public {
        vm.startPrank(transmitter);

        uint256 relativeGasPrice = 1200000;

        vm.expectEmit(false, false, false, true);
        emit GasPriceUpdated(destChainSlug, relativeGasPrice);

        gasPriceOracle.setRelativeGasPrice(destChainSlug, relativeGasPrice);

        vm.stopPrank();

        assert(
            gasPriceOracle.relativeGasPrice(destChainSlug) == relativeGasPrice
        );
    }

    function testGetGasPrices() public {
        vm.startPrank(transmitter);

        uint256 sourceGasPrice = 1200000;
        uint256 relativeGasPrice = 1100000;

        gasPriceOracle.setSourceGasPrice(sourceGasPrice);
        gasPriceOracle.setRelativeGasPrice(destChainSlug, relativeGasPrice);

        vm.stopPrank();

        (
            uint256 sourceGasPriceActual,
            uint256 relativeGasPriceActual
        ) = gasPriceOracle.getGasPrices(destChainSlug);

        assertEq(sourceGasPriceActual, sourceGasPrice);
        assertEq(relativeGasPriceActual, relativeGasPrice);
    }

    function testNonTransmitterUpdateRelativeGasPrice() public {
        vm.startPrank(nonTransmitter);

        uint256 relativeGasPrice = 1200000;

        vm.expectRevert(TransmitterNotFound.selector);
        gasPriceOracle.setRelativeGasPrice(destChainSlug, relativeGasPrice);

        vm.stopPrank();
    }

    function testNonTransmitterUpdateSrcGasPrice() public {
        vm.startPrank(nonTransmitter);

        uint256 sourceGasPrice = 1200000;

        vm.expectRevert(TransmitterNotFound.selector);
        gasPriceOracle.setSourceGasPrice(sourceGasPrice);

        vm.stopPrank();
    }

    function testNonOwnerUpdateTransmitManager() public {
        vm.startPrank(transmitter);

        vm.expectRevert();
        gasPriceOracle.setTransmitManager(transmitManager);

        vm.stopPrank();
    }
}
