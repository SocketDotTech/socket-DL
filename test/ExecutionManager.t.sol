// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract ExecutionManagerTest is Setup {
    GasPriceOracle internal gasPriceOracle;

    address public constant NATIVE_TOKEN_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    uint256 chainSlug = uint32(uint256(0x2013AA263));
    uint256 destChainSlug = uint32(uint256(0x2013AA264));
    uint256 chainSlug2 = uint32(uint256(0x2113AA263));

    uint256 immutable transmitterPrivateKey = c++;
    address transmitter;

    uint256 immutable ownerPrivateKey = c++;
    address owner;

    uint256 immutable nonExecutorPrivateKey = c++;
    address nonExecutor;

    uint256 immutable feesPayerPrivateKey = c++;
    address feesPayer;

    uint256 immutable feesWithdrawerPrivateKey = c++;
    address feesWithdrawer;

    uint256 sealGasLimit = 200000;
    uint256 proposeGasLimit = 100000;
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;
    uint256 gasPriceOracleNonce = 0;

    ExecutionManager internal executionManager;
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

    event SealGasLimitSet(uint256 gasLimit_);
    event ProposeGasLimitSet(uint256 dstChainSlug_, uint256 gasLimit_);
    event TransmitManagerUpdated(address transmitManager);
    error TransmitterNotFound();
    error InsufficientExecutionFees();
    event FeesWithdrawn(address account_, uint256 value_);

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        transmitter = vm.addr(transmitterPrivateKey);
        nonExecutor = vm.addr(nonExecutorPrivateKey);
        feesPayer = vm.addr(feesPayerPrivateKey);
        feesWithdrawer = vm.addr(feesWithdrawerPrivateKey);

        _executor = vm.addr(executorPrivateKey);

        gasPriceOracle = new GasPriceOracle(owner, chainSlug);
        executionManager = new ExecutionManager(gasPriceOracle, owner);

        signatureVerifier = new SignatureVerifier();
        transmitManager = new TransmitManager(
            signatureVerifier,
            gasPriceOracle,
            owner,
            chainSlug,
            sealGasLimit
        );

        vm.startPrank(owner);
        executionManager.grantRole(EXECUTOR_ROLE, _executor);
        transmitManager.grantRoleWithUint(chainSlug, transmitter);
        transmitManager.grantRoleWithUint(destChainSlug, transmitter);
        gasPriceOracle.setTransmitManager(transmitManager);
        vm.stopPrank();

        assertTrue(transmitManager.hasRoleWithUint(chainSlug, transmitter));
        assertTrue(transmitManager.hasRoleWithUint(destChainSlug, transmitter));

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
    }

    function testIsExecutor() public {
        bytes32 packedMessage = bytes32("RANDOM_ROOT");
        bytes memory sig = _createSignature(packedMessage, executorPrivateKey);
        (, bool isValidExecutor) = executionManager.isExecutor(
            packedMessage,
            sig
        );
        assertTrue(isValidExecutor);
    }

    function testGetMinFees() public {
        uint256 msgGasLimit = 100000;
        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            destChainSlug
        );

        //compute expected Data
        uint256 dstRelativeGasPrice = gasPriceOracle.relativeGasPrice(
            destChainSlug
        );
        uint256 expectedMinFees = msgGasLimit * dstRelativeGasPrice;

        //assert actual and expected data
        assertEq(minFees, expectedMinFees);
    }

    function testPayFees() public {
        uint256 msgGasLimit = 100000;
        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            destChainSlug
        );
        deal(feesPayer, minFees);

        assertEq(address(executionManager).balance, 0);
        assertEq(feesPayer.balance, minFees);

        vm.startPrank(feesPayer);
        executionManager.payFees{value: minFees}(msgGasLimit, destChainSlug);
        vm.stopPrank();

        assertEq(address(executionManager).balance, minFees);
        assertEq(feesPayer.balance, 0);
    }

    function testWithdrawFees() public {
        uint256 msgGasLimit = 100000;
        uint256 minFees = executionManager.getMinFees(
            msgGasLimit,
            destChainSlug
        );
        deal(feesPayer, minFees);

        assertEq(address(executionManager).balance, 0);
        assertEq(feesPayer.balance, minFees);

        vm.startPrank(feesPayer);
        executionManager.payFees{value: minFees}(msgGasLimit, destChainSlug);
        vm.stopPrank();

        assertEq(feesWithdrawer.balance, 0);

        vm.startPrank(owner);
        executionManager.withdrawFees(feesWithdrawer);
        vm.stopPrank();

        assertEq(feesWithdrawer.balance, minFees);
    }

    function testRescueNativeFunds() public {
        uint256 amount = 1e18;

        assertEq(address(executionManager).balance, 0);
        deal(address(executionManager), amount);
        assertEq(address(executionManager).balance, amount);

        hoax(owner);

        executionManager.rescueFunds(
            NATIVE_TOKEN_ADDRESS,
            feesWithdrawer,
            amount
        );

        assertEq(feesWithdrawer.balance, amount);
        assertEq(address(executionManager).balance, 0);
    }
}
