// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./Setup.t.sol";

contract ExecutionManagerTest is Setup {
    address public constant NATIVE_TOKEN_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    uint32 chainSlug = uint32(uint256(0x2013AA263));
    uint32 destChainSlug = uint32(uint256(0x2013AA264));
    uint32 chainSlug2 = uint32(uint256(0x2113AA263));
    uint256 _executionFees = 110000000000;
    uint256 executorNonce = 0;

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
    uint256 sourceGasPrice = 1200000;
    uint256 relativeGasPrice = 1100000;

    ExecutionManager internal executionManager;
    SignatureVerifier internal signatureVerifier;
    TransmitManager internal transmitManager;

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

        executionManager = new ExecutionManager(
            owner,
            chainSlug,
            signatureVerifier
        );

        signatureVerifier = new SignatureVerifier();
        transmitManager = new TransmitManager(
            signatureVerifier,
            owner,
            chainSlug
        );

        executionManager = new ExecutionManager(
            owner,
            chainSlug,
            signatureVerifier
        );

        vm.startPrank(owner);

        executionManager.grantRole(EXECUTOR_ROLE, _executor);
        executionManager.grantRole(RESCUE_ROLE, owner);
        executionManager.grantRole(WITHDRAW_ROLE, owner);

        //grant FeesUpdater Role
        executionManager.grantRoleWithSlug(FEES_UPDATER_ROLE, chainSlug, owner);

        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            chainSlug,
            transmitter
        );

        transmitManager.grantRoleWithSlug(
            TRANSMITTER_ROLE,
            destChainSlug,
            transmitter
        );

        //grant FeesUpdater Role
        executionManager.grantRoleWithSlug(
            FEES_UPDATER_ROLE,
            destChainSlug,
            owner
        );

        //set ExecutionFees for remoteChainSlug
        bytes32 feesUpdateDigest = keccak256(
            abi.encode(
                FEES_UPDATE_SIG_IDENTIFIER,
                address(executionManager),
                chainSlug,
                destChainSlug,
                executorNonce,
                _executionFees
            )
        );

        bytes memory feesUpdateSignature = _createSignature(
            feesUpdateDigest,
            ownerPrivateKey
        );

        executionManager.setExecutionFees(
            executorNonce++,
            uint32(destChainSlug),
            _executionFees,
            feesUpdateSignature
        );

        vm.stopPrank();

        assertTrue(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                chainSlug,
                transmitter
            )
        );
        assertTrue(
            transmitManager.hasRoleWithSlug(
                TRANSMITTER_ROLE,
                destChainSlug,
                transmitter
            )
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
        uint256 minFees = executionManager.getMinFees(destChainSlug);

        //compute expected Data
        uint256 expectedMinFees = msgGasLimit * relativeGasPrice;

        //assert actual and expected data
        assertEq(minFees, expectedMinFees);
    }

    function testPayFees() public {
        uint256 msgGasLimit = 100000;
        uint256 minFees = executionManager.getMinFees(destChainSlug);
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
        uint256 minFees = executionManager.getMinFees(destChainSlug);
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
