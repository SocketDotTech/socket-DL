// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vm} from "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/GasPriceOracle.sol";
import {ExecutionManager} from "../contracts/ExecutionManager.sol";
import {SignatureVerifier} from "../contracts/utils/SignatureVerifier.sol";
import {TransmitManager} from "../contracts/TransmitManager.sol";

contract ExecutionManagerTest is Test {
    GasPriceOracle internal gasPriceOracle;

    address public constant NATIVE_TOKEN_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    bytes32 private constant EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;

    uint256 chainSlug = uint32(uint256(0x2013AA263));
    uint256 destChainSlug = uint32(uint256(0x2013AA264));
    uint256 chainSlug2 = uint32(uint256(0x2113AA263));

    uint256 internal c = 1;

    uint256 immutable transmitterPrivateKey = c++;
    address transmitter;

    uint256 immutable ownerPrivateKey = c++;
    address owner;

    uint256 immutable executorPrivateKey = c++;
    address executor;

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
        executor = vm.addr(executorPrivateKey);
        nonExecutor = vm.addr(nonExecutorPrivateKey);
        feesPayer = vm.addr(feesPayerPrivateKey);
        feesWithdrawer = vm.addr(feesWithdrawerPrivateKey);

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
        executionManager.grantRole(EXECUTOR_ROLE, executor);
        transmitManager.grantRoleWithUint(chainSlug, transmitter);
        transmitManager.grantRoleWithUint(destChainSlug, transmitter);
        gasPriceOracle.setTransmitManager(transmitManager);
        vm.stopPrank();

        assertTrue(transmitManager.hasRoleWithUint(chainSlug, transmitter));
        assertTrue(transmitManager.hasRoleWithUint(destChainSlug, transmitter));

        vm.startPrank(transmitter);
        gasPriceOracle.setSourceGasPrice(sourceGasPrice);
        gasPriceOracle.setRelativeGasPrice(destChainSlug, relativeGasPrice);
        vm.stopPrank();
    }

    function testIsExecutor() public {
        assertTrue(executionManager.isExecutor(executor));
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
