// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";

contract ExecutionManagerTest is Setup {
    ExecutionManager internal executionManager;

    event FeesWithdrawn(address account_, uint256 value_);

    function setUp() public {
        initialize();
        _a.chainSlug = uint32(uint256(aChainSlug));
        _b.chainSlug = uint32(uint256(bChainSlug));
        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;
        _deployContractsOnSingleChain(
            _a,
            bChainSlug,
            isExecutionOpen,
            transmitterPrivateKeys
        );

        executionManager = _a.executionManager__;
        assertTrue(
            executionManager.hasRoleWithSlug(
                FEES_UPDATER_ROLE,
                bChainSlug,
                _socketOwner
            )
        );

        // grant role to _feesPayer to be able to call ExecutionManager
        vm.prank(executionManager.owner());
        executionManager.grantRole(SOCKET_RELAYER_ROLE, _feesPayer);

        // grant role to this contract to be able to call ExecutionManager
        vm.prank(executionManager.owner());
        executionManager.grantRole(SOCKET_RELAYER_ROLE, address(this));
    }

    function testIsExecutor() public {
        bytes32 packedMessage = bytes32("RANDOM_ROOT");
        bytes memory sig = _createSignature(packedMessage, _executorPrivateKey);
        (, bool isValidExecutor) = executionManager.isExecutor(
            packedMessage,
            sig
        );
        assertTrue(isValidExecutor);
    }

    function testGetMinFees() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        uint256 minFees = executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            bChainSlug
        );

        //assert actual and expected data
        assertEq(minFees, _executionFees);
    }

    function testGetTransmissionExecutionFees() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        (uint128 executionFees, uint128 transmissionFees) = executionManager
            .getExecutionTransmissionMinFees(
                minMsgGasLimit,
                payloadSize,
                executionParams,
                _transmissionParams,
                bChainSlug,
                address(_a.transmitManager__)
            );

        //assert actual and expected data
        assertEq(executionFees, _executionFees);
        assertEq(transmissionFees, _transmissionFees);
    }

    function testGetMinFeesWithMsgValueTooHigh() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 1000000;
        uint8 paramType = 1;
        bytes32 executionParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        vm.expectRevert(ExecutionManager.MsgValueTooHigh.selector);
        executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            bChainSlug
        );

        // also reverts if an unknown sibling slug is used
        vm.expectRevert(ExecutionManager.MsgValueTooHigh.selector);
        executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            uint32(c++)
        );
    }

    function testGetMinFeesWithMsgValueTooLow() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 1;
        uint8 paramType = 1;
        bytes32 executionParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        _setMsgValueMinThreshold(_a, bChainSlug, _msgValueMinThreshold);

        vm.expectRevert(ExecutionManager.MsgValueTooLow.selector);
        executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            bChainSlug
        );
    }

    function testGetMinFeesWithMsgValue() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 100;
        uint8 paramType = 1;
        bytes32 executionParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        uint256 minFees = executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            bChainSlug
        );

        assertEq(
            minFees,
            _executionFees + (msgValue * _relativeNativeTokenPrice) / 1e18
        );
    }

    function testGetMinFeesWithPayloadTooLong() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 10000;
        bytes32 executionParams = bytes32(
            uint256((uint256(1) << 224) | uint224(100))
        );

        vm.expectRevert(ExecutionManager.PayloadTooLarge.selector);
        executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            bChainSlug
        );
    }

    function testPayAndCheckFees() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        (uint128 executionFees, uint128 transmissionFees) = executionManager
            .getExecutionTransmissionMinFees(
                minMsgGasLimit,
                payloadSize,
                executionParams,
                _transmissionParams,
                bChainSlug,
                address(_a.transmitManager__)
            );

        uint256 totalFees = transmissionFees +
            executionFees +
            _switchboardFees +
            _verificationOverheadFees; //
        deal(_feesPayer, totalFees);

        assertEq(address(executionManager).balance, 0);

        vm.startPrank(_feesPayer);
        _a.executionManager__.payAndCheckFees{value: totalFees}(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            _switchboardFees,
            _verificationOverheadFees,
            address(_a.transmitManager__),
            address(_a.configs__[0].switchboard__),
            1
        );
        vm.stopPrank();

        assertEq(address(executionManager).balance, totalFees);
        assertEq(_feesPayer.balance, 0);

        (
            uint128 storedExecutionFees,
            uint128 storedTransmissionFees
        ) = executionManager.totalExecutionAndTransmissionFees(bChainSlug);

        assertEq(storedTransmissionFees, _transmissionFees);
        assertEq(
            storedExecutionFees,
            _executionFees + _verificationOverheadFees
        );
        assertEq(
            executionManager.totalSwitchboardFees(
                address(_a.configs__[0].switchboard__),
                bChainSlug
            ),
            _switchboardFees
        );
    }

    function testPayAndCheckFeesWithoutSocketRelayerRole() public {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(executionManager.owner());
        executionManager.revokeRole(SOCKET_RELAYER_ROLE, _feesPayer);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );

        vm.startPrank(_feesPayer);
        _a.executionManager__.payAndCheckFees{value: 0}(
            0,
            0,
            bytes32(0),
            bytes32(0),
            0,
            0,
            0,
            address(0),
            address(0),
            0
        );
        vm.stopPrank();
    }

    function testFailPayAndCheckFeesWithFeeSetTooHigh() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        uint256 totalFees = _transmissionFees +
            _executionFees +
            type(uint128).max + //_switchboardFees
            _verificationOverheadFees;

        _a.executionManager__.payAndCheckFees{value: totalFees}(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            _switchboardFees,
            _verificationOverheadFees,
            address(_a.transmitManager__),
            address(_a.configs__[0].switchboard__),
            1
        );
    }

    function testFailPayAndCheckFeesWithExecutionFeeSetTooHigh() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        _setExecutionFees(_a, _b.chainSlug, type(uint128).max);

        uint256 totalFees = _transmissionFees +
            type(uint128).max +
            _switchboardFees + //_switchboardFees
            _verificationOverheadFees;

        _a.executionManager__.payAndCheckFees{value: totalFees}(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            _switchboardFees,
            _verificationOverheadFees,
            address(_a.transmitManager__),
            address(_a.configs__[0].switchboard__),
            1
        );
    }

    function testPayAndCheckFeesWithExecutionFeeSetTooHigh() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 1000;
        uint8 paramType = 1;
        bytes32 executionParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        _setExecutionFees(_a, _b.chainSlug, type(uint128).max);
        _setRelativeNativeTokenPrice(
            _a,
            _b.chainSlug,
            _relativeNativeTokenPrice
        );

        vm.expectRevert(ExecutionManager.FeesTooHigh.selector);
        _a.executionManager__.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _b.chainSlug
        );
    }

    function testPayAndCheckFeesWithMsgValueTooHigh() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);
        deal(_feesPayer, type(uint256).max);
        hoax(_feesPayer);
        vm.expectRevert(ExecutionManager.InvalidMsgValue.selector);
        _a.executionManager__.payAndCheckFees{value: type(uint128).max}(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            _switchboardFees,
            _verificationOverheadFees,
            address(_a.transmitManager__),
            address(_a.configs__[0].switchboard__),
            1
        );
    }

    function testPayAndCheckFeesWithMsgValueTooHighWithoutSocketRelayerRole()
        public
    {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(executionManager.owner());
        executionManager.revokeRole(SOCKET_RELAYER_ROLE, _feesPayer);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );
        vm.prank(_feesPayer);
        _a.executionManager__.payAndCheckFees{value: 0}(
            0,
            0,
            bytes32(0),
            bytes32(0),
            0,
            0,
            0,
            address(0),
            address(0),
            0
        );
    }


    function testWithdrawExecutionFees() public {
        sendFeesToExecutionManager();
        uint128 amount = 100;

        // should revert with zero address
        hoax(_socketOwner);
        vm.expectRevert(ZeroAddress.selector);
        executionManager.withdrawExecutionFees(bChainSlug, amount, address(0));

        // should revert with NoPermit
        hoax(_raju);
        vm.expectRevert();
        executionManager.withdrawExecutionFees(
            bChainSlug,
            amount,
            _feesWithdrawer
        );

        vm.startPrank(_socketOwner);
        vm.expectRevert(ExecutionManager.InsufficientFees.selector);
        executionManager.withdrawExecutionFees(
            bChainSlug,
            type(uint128).max,
            _feesWithdrawer
        );

        // should fail as no receive or fallback function in socket
        vm.expectRevert("ETH_TRANSFER_FAILED");
        executionManager.withdrawExecutionFees(
            bChainSlug,
            amount,
            address(_a.socket__)
        );

        (uint128 storedExecutionFees1, ) = executionManager
            .totalExecutionAndTransmissionFees(bChainSlug);

        executionManager.withdrawExecutionFees(
            bChainSlug,
            amount,
            _feesWithdrawer
        );

        (uint128 storedExecutionFees2, ) = executionManager
            .totalExecutionAndTransmissionFees(bChainSlug);

        assertEq(_feesWithdrawer.balance, amount);
        assertEq(storedExecutionFees2, storedExecutionFees1 - amount);
    }

    function testWithdrawTransmissionFees() public {
        sendFeesToExecutionManager();

        uint128 amount = 100;

        vm.expectRevert(ExecutionManager.InsufficientFees.selector);
        executionManager.withdrawTransmissionFees(
            bChainSlug,
            type(uint128).max
        );

        (, uint128 storedTransmissionFees1) = executionManager
            .totalExecutionAndTransmissionFees(bChainSlug);

        executionManager.withdrawTransmissionFees(bChainSlug, amount);

        (, uint128 storedTransmissionFees2) = executionManager
            .totalExecutionAndTransmissionFees(bChainSlug);

        assertEq(storedTransmissionFees2, storedTransmissionFees1 - amount);
        assertEq(address(_a.transmitManager__).balance, amount);

        hoax(_socketOwner);
        _a.socket__.setExecutionManager(address(uint160(c++)));

        vm.expectRevert(TransmitManager.OnlyExecutionManager.selector);
        executionManager.withdrawTransmissionFees(bChainSlug, 100);
    }

    function testWithdrawTransmissionFeesWithoutSocketRelayerRole() public {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(executionManager.owner());
        executionManager.revokeRole(SOCKET_RELAYER_ROLE, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );

        executionManager.withdrawTransmissionFees(bChainSlug, 0);
    }

    function testWithdrawSwitchboardFees() public {
        sendFeesToExecutionManager();

        uint128 amount = 100;

        vm.expectRevert(ExecutionManager.InsufficientFees.selector);
        executionManager.withdrawSwitchboardFees(
            bChainSlug,
            _socketOwner,
            amount
        );

        uint128 storedSwitchboardFees1 = executionManager.totalSwitchboardFees(
            address(_a.configs__[0].switchboard__),
            bChainSlug
        );

        executionManager.withdrawSwitchboardFees(
            bChainSlug,
            address(_a.configs__[0].switchboard__),
            amount
        );

        uint128 storedSwitchboardFees2 = executionManager.totalSwitchboardFees(
            address(_a.configs__[0].switchboard__),
            bChainSlug
        );

        assertEq(address(_a.configs__[0].switchboard__).balance, amount);
        assertEq(storedSwitchboardFees2, storedSwitchboardFees1 - amount);
    }

    function testWithdrawSwitchboardFeesWithoutSocketRelayerRole() public {
        // revoke the SOCKET_RELAYER_ROLE
        vm.prank(executionManager.owner());
        executionManager.revokeRole(SOCKET_RELAYER_ROLE, _feesPayer);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                SOCKET_RELAYER_ROLE
            )
        );

        vm.prank(_feesPayer);
        executionManager.withdrawSwitchboardFees(bChainSlug, address(0), 0);
    }

    function sendFeesToExecutionManager() internal {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        uint256 totalFees = _transmissionFees +
            _executionFees +
            _switchboardFees +
            _verificationOverheadFees;

        _a.executionManager__.payAndCheckFees{value: totalFees}(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _transmissionParams,
            _b.chainSlug,
            _switchboardFees,
            _verificationOverheadFees,
            address(_a.transmitManager__),
            address(_a.configs__[0].switchboard__),
            1
        );

        assertEq(address(executionManager).balance, totalFees);
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;

        hoax(_socketOwner);
        vm.expectRevert();
        executionManager.rescueFunds(NATIVE_TOKEN_ADDRESS, address(0), amount);

        hoax(_socketOwner);
        _rescueNative(
            address(executionManager),
            NATIVE_TOKEN_ADDRESS,
            _feesWithdrawer,
            amount
        );
    }
}
