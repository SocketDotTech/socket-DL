// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../Setup.t.sol";

contract OpenExecutionManagerTest is Setup {
    OpenExecutionManager internal executionManager;

    error InsufficientExecutionFees();
    event FeesWithdrawn(address account_, uint256 value_);
    error MsgValueTooLow();
    error MsgValueTooHigh();
    error PayloadTooLarge();
    error InsufficientMsgValue();

    function setUp() public {
        initialize();
        _a.chainSlug = uint32(uint256(aChainSlug));
        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;
        _deployContractsOnSingleChain(
            _a,
            bChainSlug,
            true,
            transmitterPrivateKeys
        );

        executionManager = OpenExecutionManager(address(_a.executionManager__));
    }

    function testIsExecutor() public {
        bytes32 packedMessage = bytes32("RANDOM_ROOT");
        bytes memory sig = _createSignature(packedMessage, _executorPrivateKey);
        (, bool isValidExecutor) = executionManager.isExecutor(
            packedMessage,
            sig
        );
        assertTrue(isValidExecutor);

        sig = _createSignature(packedMessage, _nonExecutorPrivateKey);
        (, isValidExecutor) = executionManager.isExecutor(packedMessage, sig);
        assertTrue(isValidExecutor);
    }
}
