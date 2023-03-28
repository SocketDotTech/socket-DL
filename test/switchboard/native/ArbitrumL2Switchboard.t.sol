// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Setup.t.sol";
import "forge-std/Test.sol";
import "../../../contracts/switchboard/native/ArbitrumL2Switchboard.sol";
import "../../../contracts/TransmitManager.sol";
import "../../../contracts/GasPriceOracle.sol";
import "../../../contracts/ExecutionManager.sol";
import "../../../contracts/CapacitorFactory.sol";
import "../../../contracts/interfaces/ICapacitor.sol";

// Arbitrum Goerli -> Goerli
contract ArbitrumL2SwitchboardTest is Setup {
    bytes32[] roots;

    uint256 confirmGasLimit_ = 100;
    uint256 initiateGasLimit_ = 100;
    uint256 executionOverhead_ = 100;
    address remoteNativeSwitchboard_ =
        0x3f0121d91B5c04B716Ea960790a89b173da7929c;
    IGasPriceOracle gasPriceOracle_;

    ArbitrumL2Switchboard arbitrumL2Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        _a.chainSlug = uint32(uint256(421613));
        _b.chainSlug = uint32(uint256(5));

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        deal(socketAddress, 2e18);

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            address(arbitrumL2Switchboard.arbsys__()),
            0,
            1000000,
            100,
            abi.encode(msg.sender)
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            _a,
            address(singleCapacitor),
            _b.chainSlug
        );
        vm.mockCall(
            address(arbitrumL2Switchboard.arbsys__()),
            abi.encodeWithSelector(
                arbitrumL2Switchboard.arbsys__().sendTxToL1.selector
            ),
            abi.encode("0x")
        );

        arbitrumL2Switchboard.initateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _watcher = vm.addr(_watcherPrivateKey);
        _transmitter = vm.addr(_transmitterPrivateKey);

        deployContractsOnSingleChain(_a, _b.chainSlug, transmitterPrivateKeys_);
    }

    function deployContractsOnSingleChain(
        ChainContext storage cc_,
        uint256 remoteChainSlug_,
        uint256[] memory transmitterPrivateKeys_
    ) internal {
        // deploy socket setup
        deploySocket(cc_, _socketOwner);

        vm.startPrank(_socketOwner);

        cc_.transmitManager__.grantRole(
            GAS_LIMIT_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );

        vm.stopPrank();

        hoax(_socketOwner);
        cc_.transmitManager__.setProposeGasLimit(
            remoteChainSlug_,
            _proposeGasLimit
        );

        SocketConfigContext memory scc_ = addArbitrumL2Switchboard(
            cc_,
            remoteChainSlug_,
            _capacitorType
        );
        cc_.configs__.push(scc_);

        // add roles
        hoax(_socketOwner);
        cc_.executionManager__.grantRole(EXECUTOR_ROLE, _executor);
        _addTransmitters(transmitterPrivateKeys_, cc_, remoteChainSlug_);
    }

    function deploySocket(
        ChainContext storage cc_,
        address deployer_
    ) internal {
        vm.startPrank(deployer_);

        cc_.hasher__ = new Hasher();
        cc_.sigVerifier__ = new SignatureVerifier();
        cc_.capacitorFactory__ = new CapacitorFactory(deployer_);
        cc_.gasPriceOracle__ = new GasPriceOracle(
            deployer_,
            uint32(cc_.chainSlug)
        );
        cc_.executionManager__ = new ExecutionManager(
            cc_.gasPriceOracle__,
            deployer_
        );

        cc_.transmitManager__ = new TransmitManager(
            cc_.sigVerifier__,
            cc_.gasPriceOracle__,
            deployer_,
            cc_.chainSlug,
            _sealGasLimit
        );

        cc_.gasPriceOracle__.grantRole(GOVERNANCE_ROLE, deployer_);
        cc_.gasPriceOracle__.grantRole(GAS_LIMIT_UPDATER_ROLE, deployer_);

        cc_.gasPriceOracle__.setTransmitManager(cc_.transmitManager__);

        cc_.socket__ = new Socket(
            uint32(cc_.chainSlug),
            address(cc_.hasher__),
            address(cc_.transmitManager__),
            address(cc_.executionManager__),
            address(cc_.capacitorFactory__),
            deployer_
        );

        vm.stopPrank();
    }

    function addArbitrumL2Switchboard(
        ChainContext storage cc_,
        uint256 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        arbitrumL2Switchboard = new ArbitrumL2Switchboard(
            confirmGasLimit_,
            initiateGasLimit_,
            executionOverhead_,
            _socketOwner,
            cc_.gasPriceOracle__
        );

        vm.startPrank(_socketOwner);
        arbitrumL2Switchboard.grantRole(GAS_LIMIT_UPDATER_ROLE, _socketOwner);
        arbitrumL2Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        arbitrumL2Switchboard.setExecutionOverhead(_executionOverhead);
        arbitrumL2Switchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
        vm.stopPrank();

        scc_ = registerSwitchbaord(
            cc_,
            _socketOwner,
            address(arbitrumL2Switchboard),
            remoteChainSlug_,
            capacitorType_
        );
    }

    function registerSwitchbaord(
        ChainContext storage cc_,
        address deployer_,
        address switchBoardAddress_,
        uint256 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(deployer_);
        cc_.socket__.registerSwitchBoard(
            switchBoardAddress_,
            DEFAULT_BATCH_LENGTH,
            uint32(remoteChainSlug_),
            uint32(capacitorType_)
        );

        scc_.siblingChainSlug = remoteChainSlug_;
        scc_.capacitor__ = cc_.socket__.capacitors__(
            switchBoardAddress_,
            remoteChainSlug_
        );
        singleCapacitor = scc_.capacitor__;

        scc_.decapacitor__ = cc_.socket__.decapacitors__(
            switchBoardAddress_,
            remoteChainSlug_
        );
        scc_.switchboard__ = ISwitchboard(switchBoardAddress_);

        arbitrumL2Switchboard.grantRole(GOVERNANCE_ROLE, deployer_);
        vm.stopPrank();
    }
}
