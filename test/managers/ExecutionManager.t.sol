// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";

contract ExecutionManagerTest is Setup {
    ExecutionManagerDF internal executionManager;
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

        uint256 executionFees = minMsgGasLimit *
            gasPrice +
            overhead +
            payloadSize *
            perByteCost;

        //assert actual and expected data
        assertEq(minFees, executionFees);
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

        uint256 executionFeesCalc = minMsgGasLimit *
            gasPrice +
            overhead +
            payloadSize *
            perByteCost;

        assertEq(executionFees, executionFeesCalc);
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

        vm.expectRevert(ExecutionManagerDF.MsgValueTooHigh.selector);
        executionManager.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            bChainSlug
        );

        // also reverts if an unknown sibling slug is used
        vm.expectRevert(ExecutionManagerDF.MsgValueTooHigh.selector);
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

        vm.expectRevert(ExecutionManagerDF.MsgValueTooLow.selector);
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

        uint256 executionFeesCalc = minMsgGasLimit *
            gasPrice +
            overhead +
            payloadSize *
            perByteCost;

        assertEq(
            minFees,
            executionFeesCalc + (msgValue * _relativeNativeTokenPrice) / 1e18
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

        uint256 executionFeesCalc = minMsgGasLimit *
            gasPrice +
            overhead +
            payloadSize *
            perByteCost;

        assertEq(storedTransmissionFees, _transmissionFees);
        assertEq(
            storedExecutionFees,
            executionFeesCalc + _verificationOverheadFees
        );
        assertEq(
            executionManager.totalSwitchboardFees(
                address(_a.configs__[0].switchboard__),
                bChainSlug
            ),
            _switchboardFees
        );
    }

    function testFailPayAndCheckFeesWithFeeSetTooHigh() public {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        uint256 executionFeesCalc = minMsgGasLimit *
            gasPrice +
            overhead +
            payloadSize *
            perByteCost;

        uint256 totalFees = _transmissionFees +
            executionFeesCalc +
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

        IExecutionManager.ExecutionFeesParam
            memory executionFees = IExecutionManager.ExecutionFeesParam(
                gasPrice,
                perByteCost,
                overhead
            );
        _setExecutionFees(_a, _b.chainSlug, executionFees);

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

    function testPayAndCheckFeesWithExecutionFeeTooHigh() public {
        uint256 minMsgGasLimit = type(uint128).max;
        uint256 payloadSize = 1000;
        uint256 msgValue = 1000;
        uint8 paramType = 1;
        bytes32 executionParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        IExecutionManager.ExecutionFeesParam
            memory executionFees = IExecutionManager.ExecutionFeesParam(
                type(uint80).max,
                type(uint80).max,
                type(uint80).max
            );
        _setExecutionFees(_a, _b.chainSlug, executionFees);
        _setRelativeNativeTokenPrice(
            _a,
            _b.chainSlug,
            _relativeNativeTokenPrice
        );

        vm.expectRevert(ExecutionManagerDF.FeesTooHigh.selector);
        _a.executionManager__.getMinFees(
            minMsgGasLimit,
            payloadSize,
            executionParams,
            _b.chainSlug
        );

        vm.expectRevert(ExecutionManagerDF.PayloadTooLarge.selector);
        _a.executionManager__.getMinFees(
            minMsgGasLimit,
            6000,
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
        vm.expectRevert(ExecutionManagerDF.InvalidMsgValue.selector);
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
        vm.expectRevert(ExecutionManagerDF.InsufficientFees.selector);
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

        vm.expectRevert(ExecutionManagerDF.InsufficientFees.selector);
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

    function testWithdrawSwitchboardFees() public {
        sendFeesToExecutionManager();

        uint128 amount = 100;

        vm.expectRevert(ExecutionManagerDF.InsufficientFees.selector);
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

    function sendFeesToExecutionManager() internal {
        uint256 minMsgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 executionParams = bytes32(0);

        uint256 executionFeesCalc = minMsgGasLimit *
            gasPrice +
            overhead +
            payloadSize *
            perByteCost;

        uint256 totalFees = _transmissionFees +
            executionFeesCalc +
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
