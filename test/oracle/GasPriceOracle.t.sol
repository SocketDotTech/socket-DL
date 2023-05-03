// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";

contract GasPriceOracleTest is Setup {
    GasPriceOracle internal gasPriceOracle;
    uint32 chainSlug = uint32(uint256(0x2013AA263));
    uint32 destChainSlug = uint32(uint256(0x2013AA264));
    uint256 transmitterPrivateKey = c++;
    address immutable transmitter = vm.addr(transmitterPrivateKey);

    address immutable owner = address(uint160(c++));
    address immutable nonTransmitter = address(uint160(c++));
    uint256 gasLimit = 200000;
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event RelativeGasPriceUpdated(
        uint256 dstChainSlug_,
        uint256 relativeGasPrice_
    );
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
        transmitManager.grantRoleWithSlug(
            "TRANSMITTER_ROLE",
            chainSlug,
            transmitter
        );
        transmitManager.grantRoleWithSlug(
            "TRANSMITTER_ROLE",
            destChainSlug,
            transmitter
        );
        gasPriceOracle.grantRole(GOVERNANCE_ROLE, owner);

        vm.expectEmit(false, false, false, true);
        emit TransmitManagerUpdated(address(transmitManager));
        gasPriceOracle.setTransmitManager(transmitManager);

        vm.stopPrank();
    }

    function testSetSourceGasPrice() public {
        uint256 sourceGasPrice = 1200000;

        vm.expectEmit(false, false, false, true);
        emit SourceGasPriceUpdated(sourceGasPrice);

        bytes32 digest = keccak256(
            abi.encode(chainSlug, gasPriceOracleNonce, sourceGasPrice)
        );
        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

        gasPriceOracle.setSourceGasPrice(
            gasPriceOracleNonce++,
            sourceGasPrice,
            sig
        );
        assert(gasPriceOracle.sourceGasPrice() == sourceGasPrice);
    }

    function testSetRelativeGasPrice() public {
        uint256 relativeGasPrice = 1200000;

        vm.expectEmit(false, false, false, true);
        emit RelativeGasPriceUpdated(destChainSlug, relativeGasPrice);

        bytes32 digest = keccak256(
            abi.encode(
                chainSlug,
                destChainSlug,
                gasPriceOracleNonce,
                relativeGasPrice
            )
        );
        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

        gasPriceOracle.setRelativeGasPrice(
            destChainSlug,
            gasPriceOracleNonce++,
            relativeGasPrice,
            sig
        );

        assert(
            gasPriceOracle.relativeGasPrice(destChainSlug) == relativeGasPrice
        );
    }

    function testGetGasPrices() public {
        uint256 sourceGasPrice = 1200000;
        uint256 relativeGasPrice = 1100000;

        bytes32 digest = keccak256(
            abi.encode(chainSlug, gasPriceOracleNonce, sourceGasPrice)
        );
        bytes memory sig = _createSignature(digest, transmitterPrivateKey);

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

        (
            uint256 sourceGasPriceActual,
            uint256 relativeGasPriceActual
        ) = gasPriceOracle.getGasPrices(destChainSlug);

        assertEq(sourceGasPriceActual, sourceGasPrice);
        assertEq(relativeGasPriceActual, relativeGasPrice);
    }

    function testNonTransmitterUpdateRelativeGasPrice() public {
        uint256 relativeGasPrice = 1200000;

        vm.expectRevert(TransmitterNotFound.selector);
        bytes32 digest = keccak256(
            abi.encode(
                chainSlug,
                destChainSlug,
                gasPriceOracleNonce,
                relativeGasPrice
            )
        );
        bytes memory sig = _createSignature(digest, _altTransmitterPrivateKey);

        gasPriceOracle.setRelativeGasPrice(
            uint32(destChainSlug),
            gasPriceOracleNonce++,
            relativeGasPrice,
            sig
        );
    }

    function testNonTransmitterUpdateSrcGasPrice() public {
        uint256 sourceGasPrice = 1200000;

        vm.expectRevert(TransmitterNotFound.selector);
        bytes32 digest = keccak256(
            abi.encode(chainSlug, gasPriceOracleNonce, sourceGasPrice)
        );
        bytes memory sig = _createSignature(digest, _altTransmitterPrivateKey);

        gasPriceOracle.setSourceGasPrice(
            gasPriceOracleNonce++,
            sourceGasPrice,
            sig
        );
    }

    function testNonOwnerUpdateTransmitManager() public {
        hoax(transmitter);
        vm.expectRevert();
        gasPriceOracle.setTransmitManager(transmitManager);
    }
}
