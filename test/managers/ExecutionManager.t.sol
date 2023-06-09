// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Setup.t.sol";

contract ExecutionManagerTest is Setup {
    ExecutionManager internal executionManager;

    error InsufficientExecutionFees();
    event FeesWithdrawn(address account_, uint256 value_);
    error MsgValueTooLow();
    error MsgValueTooHigh();
    error PayloadTooLarge();
    error InsufficientMsgValue();

    function setUp() public {
        initialise();
        _a.chainSlug = uint32(uint256(aChainSlug));
        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;
        _deployContractsOnSingleChain(_a, bChainSlug, transmitterPivateKeys);

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
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 extraParams = bytes32(0);

        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );

        //assert actual and expected data
        assertEq(minFees, _executionFees);
    }

    function testGetMinFeesWithMsgValueTooHigh() public {
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 1000000;
        uint8 paramType = 1;
        bytes32 extraParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        vm.expectRevert(MsgValueTooHigh.selector);
        executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );
    }

    function testGetMinFeesWithMsgValueTooLow() public {
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 1;
        uint8 paramType = 1;
        bytes32 extraParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        _setMsgValueMinThreshold(_a, _msgValueMinThreshold);

        vm.expectRevert(MsgValueTooLow.selector);
        executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );
    }

    function testGetMinFeesWithMsgValue() public {
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 1000;
        uint256 msgValue = 100;
        uint8 paramType = 1;
        bytes32 extraParams = bytes32(
            uint256((uint256(paramType) << 248) | uint248(msgValue))
        );

        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );

        assertEq(
            minFees,
            _executionFees + (msgValue * _relativeNativeTokenPrice) / 1e18
        );
    }

    function testGetMinFeesWithPayloadTooLong() public {
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 10000;
        bytes32 extraParams = bytes32(
            uint256((uint256(1) << 224) | uint224(100))
        );

        vm.expectRevert(PayloadTooLarge.selector);
        executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );
    }

    function testPayFees() public {
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 extraParams = bytes32(0);

        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );
        deal(_feesPayer, minFees);

        assertEq(address(executionManager).balance, 0);
        assertEq(_feesPayer.balance, minFees);

        vm.startPrank(_feesPayer);
        executionManager.payFees{value: minFees}(msgGasLimit, bChainSlug);
        vm.stopPrank();

        assertEq(address(executionManager).balance, minFees);
        assertEq(_feesPayer.balance, 0);
    }

    function testWithdrawFees() public {
        uint256 msgGasLimit = 100000;
        uint256 payloadSize = 1000;
        bytes32 extraParams = bytes32(0);

        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            payloadSize,
            extraParams,
            bChainSlug
        );
        deal(_feesPayer, minFees);

        assertEq(address(executionManager).balance, 0);
        assertEq(_feesPayer.balance, minFees);

        vm.startPrank(_feesPayer);
        executionManager.payFees{value: minFees}(msgGasLimit, bChainSlug);
        vm.stopPrank();

        assertEq(_feesWithdrawer.balance, 0);

        vm.startPrank(_socketOwner);
        executionManager.withdrawFees(_feesWithdrawer);
        vm.stopPrank();

        assertEq(_feesWithdrawer.balance, minFees);
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
