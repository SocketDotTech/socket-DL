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
    }

    function testGrantTransmitterRole() public {
        vm.startPrank(owner);
        transmitManager.grantTransmitterRole(chainSlug, transmitter);
        vm.stopPrank();

        assertTrue(transmitManager.isTransmitter(transmitter, chainSlug));
    }

}
