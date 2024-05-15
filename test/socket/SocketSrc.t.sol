// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";
import "../../contracts/examples/Counter.sol";

contract SocketSrcTest is Setup {
    Counter srcCounter__;
    Counter dstCounter__;

    uint256 addAmount = 100;
    uint256 subAmount = 40;
    bool isFast = true;
    bytes32[] roots;

    error InvalidTransmitter();
    error InsufficientFees();
    event Sealed(
        address indexed transmitter,
        bytes32 indexed packetId,
        uint256 batchSize,
        bytes32 root,
        bytes signature
    );

    event MessageTransmitted(
        uint32 localChainSlug,
        address localPlug,
        uint32 dstChainSlug,
        address dstPlug,
        uint256 msgId,
        uint256 minMsgGasLimit,
        uint256 executionFee,
        uint256 fees,
        bytes payload
    );

    // Event triggered when a new switchboard is added
    event SwitchboardAdded(
        address switchboard,
        uint32 siblingChainSlug,
        address capacitor,
        address decapacitor,
        uint256 maxPacketLength,
        uint256 capacitorType
    );

    // Event triggered when a new switchboard is added
    event SiblingSwitchboardUpdated(
        address switchboard,
        uint32 siblingChainSlug,
        address siblingSwitchboard
    );

    function setUp() external {
        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _dualChainSetup(transmitterPrivateKeys);
        _deployPlugContracts();

        uint256 index = isFast ? 0 : 1;
        _configPlugContracts(index);

        // grant role to this contract to be able to call SrcSocket
        vm.prank(_a.socket__.owner());
        _a.socket__.grantRole(SOCKET_RELAYER_ROLE, address(this));

        // grant role to SrcCounter to be able to call Socket
        vm.prank(_a.socket__.owner());
        _a.socket__.grantRole(SOCKET_RELAYER_ROLE, address(srcCounter__));

        // grant role to SrcSocket to be able to call ExecutionManager
        vm.prank(_a.socket__.owner());
        _a.executionManager__.grantRole(SOCKET_RELAYER_ROLE, address(_a.socket__));
    }

    function testOutboundWithoutSocketRelayerRole() external {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(_b.socket__.owner());
        _b.socket__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        _b.socket__.outbound(
            _a.chainSlug,
            0,
            bytes32(0),
            bytes32(0),
            bytes("")
        );
    }

    function testSealWithoutSocketRelayerRole() external {
        // grant role to this contract to be able to call SrcSocket
        vm.prank(_a.socket__.owner());
        _a.socket__.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        _a.socket__.seal(
            0,
            address(0),
            "0x"
        );
    }

    function testRegisterSwitchboardForSibling() external {
        uint32 siblingChainSlug_ = uint32(c++);
        uint256 maxPacketLength_ = DEFAULT_BATCH_LENGTH;
        uint256 capacitorType_ = 1;
        address switchboard = address(uint160(c++));
        address siblingSwitchboard_ = address(uint160(c++));

        address expectedCapacitor = 0x069B4B6deECf1352726B90c47C88d024595c033D;
        address expectedDecapacitor = 0xB166304f5613cb56C8E8Ce7316dd51067388302D;

        hoax(switchboard);
        vm.expectEmit(false, false, false, true);
        emit SwitchboardAdded(
            switchboard,
            siblingChainSlug_,
            expectedCapacitor,
            expectedDecapacitor,
            DEFAULT_BATCH_LENGTH,
            capacitorType_
        );
        vm.expectEmit(false, false, false, true);
        emit SiblingSwitchboardUpdated(
            switchboard,
            siblingChainSlug_,
            siblingSwitchboard_
        );
        _a.socket__.registerSwitchboardForSibling(
            siblingChainSlug_,
            maxPacketLength_,
            capacitorType_,
            siblingSwitchboard_
        );

        assertEq(
            expectedCapacitor,
            address(_a.socket__.capacitors__(switchboard, siblingChainSlug_))
        );
        assertEq(
            expectedDecapacitor,
            address(_a.socket__.decapacitors__(switchboard, siblingChainSlug_))
        );
    }

    function testPlugConfiguration() external {
        uint256 index = isFast ? 0 : 1;

        (
            address siblingPlug,
            address inboundSwitchboard__,
            address outboundSwitchboard__,
            address capacitor__,
            address decapacitor__
        ) = _a.socket__.getPlugConfig(address(srcCounter__), _b.chainSlug);

        assertEq(siblingPlug, address(dstCounter__));
        assertEq(
            inboundSwitchboard__,
            address(_a.configs__[index].switchboard__)
        );
        assertEq(
            outboundSwitchboard__,
            address(_a.configs__[index].switchboard__)
        );
        assertEq(capacitor__, address(_a.configs__[index].capacitor__));
        assertEq(decapacitor__, address(_a.configs__[index].decapacitor__));
    }

    function testGetMinFeesOnSocketSrc() external {
        // Checking fees for single capacitor, so no need to use maxPacketLength
        uint256 index = isFast ? 0 : 1;

        uint256 executionFee;
        {
            (uint256 switchboardFees, uint256 verificationFee) = _a
                .configs__[index]
                .switchboard__
                .getMinFees(_b.chainSlug);

            uint256 transmitFees;
            (executionFee, transmitFees) = _a
                .executionManager__
                .getExecutionTransmissionMinFees(
                    _minMsgGasLimit,
                    100,
                    bytes32(0),
                    _transmissionParams,
                    _b.chainSlug,
                    address(_a.transmitManager__)
                );

            uint256 minFeesExpected = transmitFees +
                switchboardFees +
                verificationFee +
                executionFee;

            uint256 minFeesActual = _a.socket__.getMinFees(
                _minMsgGasLimit,
                1000,
                bytes32(0),
                _transmissionParams,
                _b.chainSlug,
                address(srcCounter__)
            );

            assertEq(minFeesActual, minFeesExpected);
        }

        // revert on wrong inputs

        // wrong payload size
        vm.expectRevert(ExecutionManager.PayloadTooLarge.selector);
        _a.socket__.getMinFees(
            _minMsgGasLimit,
            4000,
            bytes32(0),
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );

        // wrong sibling slug, revert because capacitor is address(0)
        vm.expectRevert();
        _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            bytes32(0),
            _transmissionParams,
            uint32(c++),
            address(srcCounter__)
        );

        // msg value not in range
        uint256 msgValue = _msgValueMaxThreshold + 100;
        bytes32 executionParams = bytes32(
            uint256((uint256(1) << 248) | uint248(msgValue))
        );
        vm.expectRevert(ExecutionManager.MsgValueTooHigh.selector);
        _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );

        msgValue = 1;
        executionParams = bytes32(
            uint256((uint256(1) << 248) | uint248(msgValue))
        );
        vm.expectRevert(ExecutionManager.MsgValueTooLow.selector);
        _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );

        // Revert if msg.value is greater than the maximum uint128 value.
        msgValue = type(uint136).max;
        executionParams = bytes32(
            uint256((uint256(1) << 248) | uint248(msgValue))
        );
        vm.expectRevert();
        _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );
    }

    function testOutboundFromSocketSrc() external {
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );

        uint256 minFees = _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            bytes32(0),
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );

        hoax(address(srcCounter__));

        _a.socket__.outbound{value: minFees}(
            _b.chainSlug,
            _minMsgGasLimit,
            bytes32(0),
            _transmissionParams,
            payload
        );
    }

    function testOutboundForUnregisteredSibling() external {
        uint32 unknownSlug = uint32(c++);
        uint256 amount = 100;
        bytes memory payload = abi.encode(
            keccak256("OP_ADD"),
            amount,
            _plugOwner
        );

        // revert if no sibling plug is found for the given chain
        vm.expectRevert(SocketSrc.PlugDisconnected.selector);
        hoax(address(srcCounter__));
        _a.socket__.outbound{value: 100}(
            unknownSlug,
            _minMsgGasLimit,
            bytes32(0),
            _transmissionParams,
            payload
        );
    }

    function testSendMessageAndSealSuccessfully() external {
        uint256 index = isFast ? 0 : 1;
        address capacitor = address(_a.configs__[index].capacitor__);

        sendOutboundMessage();
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
            emit Sealed(
                _transmitter,
                packetId_,
                DEFAULT_BATCH_LENGTH,
                root_,
                sig_
            );

            _sealOnSrc(_a, capacitor, DEFAULT_BATCH_LENGTH, sig_);
        }
    }

    function testSealWithNonTransmitter() public {
        uint256 index = isFast ? 0 : 1;
        address capacitor = address(_a.configs__[index].capacitor__);

        sendOutboundMessage();

        uint256 fakeTransmitterKey = c++;
        {
            (, , bytes memory sig_) = getLatestSignature(
                _a,
                capacitor,
                _b.chainSlug,
                fakeTransmitterKey
            );

            vm.expectRevert(InvalidTransmitter.selector);
            _sealOnSrc(_a, capacitor, DEFAULT_BATCH_LENGTH, sig_);
        }
    }

    function testOutboundWithInSufficientFees() external {
        uint256 amount = 100;

        hoax(_plugOwner);
        vm.expectRevert(InsufficientFees.selector);
        srcCounter__.remoteAddOperation{value: 0}(
            _b.chainSlug,
            amount,
            _minMsgGasLimit,
            bytes32(0),
            bytes32(0)
        );
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;

        hoax(_socketOwner);
        vm.expectRevert();
        _a.socket__.rescueFunds(NATIVE_TOKEN_ADDRESS, address(0), amount);

        hoax(_socketOwner);
        _rescueNative(
            address(_a.socket__),
            NATIVE_TOKEN_ADDRESS,
            _fundRescuer,
            amount
        );
    }

    function getLatestSignature(
        ChainContext memory src_,
        address capacitor_,
        uint32 remoteChainSlug_,
        uint256 transmitterPrivateKey_
    ) public view returns (bytes32 root, bytes32 packetId, bytes memory sig) {
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

    function sendOutboundMessage() internal {
        uint256 amount = 100;

        uint256 minFees = _a.socket__.getMinFees(
            _minMsgGasLimit,
            1000,
            bytes32(0),
            _transmissionParams,
            _b.chainSlug,
            address(srcCounter__)
        );

        hoax(_plugOwner);
        srcCounter__.remoteAddOperation{value: minFees}(
            _b.chainSlug,
            amount,
            _minMsgGasLimit,
            bytes32(0),
            bytes32(0)
        );
    }
}
