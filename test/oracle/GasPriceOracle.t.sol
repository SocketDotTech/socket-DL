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
    uint256 gasLimit = 200000;
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event GasPriceUpdated(uint256 dstChainSlug_, uint256 relativeGasPrice_);
    event TransmitManagerUpdated(address transmitManager);
    event SourceGasPriceUpdated(uint256 sourceGasPrice);

    function setUp() public {
        gasPriceOracle = new GasPriceOracle(owner, chainSlug);
        signatureVerifier = new SignatureVerifier();
        transmitManager = new TransmitManager(signatureVerifier, 
        gasPriceOracle, owner, chainSlug, gasLimit);
        vm.startPrank(owner);
        transmitManager.grantTransmitterRole(chainSlug, transmitter);
        transmitManager.grantTransmitterRole(destChainSlug, transmitter);
        gasPriceOracle.setTransmitManager(transmitManager);
        vm.stopPrank();
    }

    function testSetSourceGasPrice() public {

        vm.startPrank(transmitter);

        gasPriceOracle.setSourceGasPrice(1200000);

        vm.stopPrank();

        assert(gasPriceOracle.sourceGasPrice() == 1200000);
    }

    function testSetRelativeGasPrice() public {

        vm.startPrank(transmitter);

        gasPriceOracle.setRelativeGasPrice(destChainSlug, 1200000);

        vm.stopPrank();

        vm.expectEmit(false, false, false, true);
        emit GasPriceUpdated(destChainSlug, 1200000);

        assert(gasPriceOracle.relativeGasPrice(destChainSlug) == 1200000);
    }

    function testGetGasPrices() public {
        vm.startPrank(transmitter);

        gasPriceOracle.setSourceGasPrice(1200000);
        gasPriceOracle.setRelativeGasPrice(destChainSlug, 1100000);

        vm.stopPrank();

        (uint256 sourceGasPrice, uint256 relativeGasPrice) = gasPriceOracle.getGasPrices(destChainSlug);

        assertEq(sourceGasPrice , uint256(1200000));
        assertEq(relativeGasPrice , uint256(1100000));
    }



}
