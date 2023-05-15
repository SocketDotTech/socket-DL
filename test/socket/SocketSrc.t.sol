// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";
import "../../contracts/examples/Counter.sol";

contract SocketSrcTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;

    uint256 sealGasLimit = 200000;
    uint256 proposeGasLimit = 100000;
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;

    bool isFast = true;
    bytes32[] roots;

    error InvalidAttester();
    error InsufficientFees();
    event PacketVerifiedAndSealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        bytes32 root,
        bytes signature
    );

    event MessageTransmitted(
        uint32 localChainSlug,
        address localPlug,
        uint32 dstChainSlug,
        address dstPlug,
        uint256 msgId,
        uint256 msgGasLimit,
        uint256 executionFee,
        uint256 fees,
        bytes payload
    );

    function setUp() external {
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPivateKeys);
        _deployPlugContracts();

        uint256 index = isFast ? 0 : 1;
        _configPlugContracts(index);

        bytes32 digest = keccak256(
            abi.encode(
                address(_a.gasPriceOracle__),
                _a.chainSlug,
                gasPriceOracleNonce,
                sourceGasPrice
            )
        );
        bytes memory sig = _createSignature(digest, _transmitterPrivateKey);

        _a.gasPriceOracle__.setSourceGasPrice(
            gasPriceOracleNonce++,
            sourceGasPrice,
            sig
        );

        digest = keccak256(
            abi.encode(
                address(_a.gasPriceOracle__),
                _a.chainSlug,
                _b.chainSlug,
                gasPriceOracleNonce,
                relativeGasPrice
            )
        );
        sig = _createSignature(digest, _transmitterPrivateKey);

        _a.gasPriceOracle__.setRelativeGasPrice(
            _b.chainSlug,
            gasPriceOracleNonce++,
            relativeGasPrice,
            sig
        );
    }

    function testGetMinFeesOnSocketSrc() external {
        uint256 index = isFast ? 0 : 1;

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 transmitFees = _a.transmitManager__.getMinFees(
                _b.chainSlug
            );
            executionFee = _a.executionManager__.getMinFees(_b.chainSlug);

            uint256 minFeesExpected = transmitFees +
                switchboardFees +
                verificationFee +
                executionFee;

            uint256 minFeesActual = _a.socket__.getMinFees(
                _msgGasLimit,
                _b.chainSlug,
                address(srcCounter__)
            );

            assertEq(minFeesActual, minFeesExpected);
        }
    }

    function testOutboundFromSocketSrc() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );

        uint256 index = isFast ? 0 : 1;

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);
            executionFee = _a.executionManager__.getMinFees(_b.chainSlug);

            hoax(address(srcCounter__));

            _a.socket__.outbound{
                value: switchboardFees +
                    socketFees +
                    verificationFee +
                    executionFee
            }(_b.chainSlug, _msgGasLimit, payload);
        }
    }

    function testSendMessageAndSealSuccessfully() external {
        uint256 amount = 100;

        uint256 index = isFast ? 0 : 1;
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);
            executionFee = _a.executionManager__.getMinFees(_b.chainSlug);

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{
                value: switchboardFees +
                    socketFees +
                    verificationFee +
                    executionFee
            }(_b.chainSlug, amount, _msgGasLimit);
        }

        {
            (
                bytes32 root_,
                bytes32 packetId_,
                bytes memory sig_
            ) = getLatestSignature(
                    _a,
                    capacitor,
                    _b.chainSlug,
                    _transmitterPrivateKey
                );

            vm.expectEmit(false, false, false, true);
            emit PacketVerifiedAndSealed(_transmitter, packetId_, root_, sig_);

            _sealOnSrc(_a, capacitor, sig_);
        }
    }

    function testSealWithNonTransmitter() public {
        uint256 amount = 100;

        uint256 index = isFast ? 0 : 1;
        address capacitor = address(_a.configs__[index].capacitor__);

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 socketFees = _a.transmitManager__.getMinFees(_b.chainSlug);
            executionFee = _a.executionManager__.getMinFees(_b.chainSlug);

            hoax(_plugOwner);
            srcCounter__.remoteAddOperation{
                value: switchboardFees +
                    socketFees +
                    verificationFee +
                    executionFee
            }(_b.chainSlug, amount, _msgGasLimit);
        }

        uint256 fakeTransmitterKey = c++;
        {
            (, , bytes memory sig_) = getLatestSignature(
                _a,
                capacitor,
                _b.chainSlug,
                fakeTransmitterKey
            );

            vm.expectRevert(InvalidAttester.selector);
            _sealOnSrc(_a, capacitor, sig_);
        }
    }

    function testOutboundWithInSufficientFees() external {
        uint256 amount = 100;

        hoax(_plugOwner);
        vm.expectRevert(InsufficientFees.selector);
        srcCounter__.remoteAddOperation{value: 0}(
            _b.chainSlug,
            amount,
            _msgGasLimit
        );
    }

    function getLatestSignature(
        ChainContext memory src_,
        address capacitor_,
        uint32 remoteChainSlug_,
        uint256 transmitterPrivateKey_
    ) public returns (bytes32 root, bytes32 packetId, bytes memory sig) {
        uint256 id;
        (root, id) = ICapacitor(capacitor_).getNextPacketToBeSealed();
        packetId = _getPackedId(capacitor_, src_.chainSlug, id);
        bytes32 digest = keccak256(
            abi.encode(versionHash, remoteChainSlug_, packetId, root)
        );

        sig = _createSignature(digest, transmitterPrivateKey_);
    }

    function _deployPlugContracts() internal {
        vm.startPrank(_plugOwner);

        // deploy counters
        srcCounter__ = new Counter(address(_a.socket__));
        dstCounter__ = new Counter(address(_b.socket__));

        vm.stopPrank();
    }

    function _configPlugContracts(uint256 socketConfigIndex) internal {
        hoax(_plugOwner);
        srcCounter__.setSocketConfig(
            _b.chainSlug,
            address(dstCounter__),
            address(_a.configs__[socketConfigIndex].switchboard__)
        );

        hoax(_plugOwner);
        dstCounter__.setSocketConfig(
            _a.chainSlug,
            address(srcCounter__),
            address(_b.configs__[socketConfigIndex].switchboard__)
        );
    }
}
