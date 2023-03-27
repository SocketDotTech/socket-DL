// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Setup.t.sol";
import "forge-std/Test.sol";
import "../../../contracts/switchboard/native/PolygonL2Switchboard.sol";
import "../../../contracts/TransmitManager.sol";
import "../../../contracts/GasPriceOracle.sol";
import "../../../contracts/ExecutionManager.sol";
import "../../../contracts/CapacitorFactory.sol";
import "../../../contracts/interfaces/ICapacitor.sol";

// Goerli -> Optimism-Goerli
contract PolygonL2SwitchboardTest is Setup {
    bytes32[] roots;

    uint256 l1ReceiveGasLimit_ = 300000;
    uint256 initialConfirmationGasLimit_ = 300000;
    uint256 executionOverhead_ = 300000;
    address fxChild_ = 0xCf73231F28B7331BBe3124B907840A94851f9f11;

    IGasPriceOracle gasPriceOracle_;

    PolygonL2Switchboard polygonL2Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        _a.chainSlug = uint32(uint256(80001));
        _b.chainSlug = uint32(uint256(5));

        uint256 fork = vm.createFork(
            vm.envString("POLYGON_MUMBAI_RPC"),
            32375450
        );
        vm.selectFork(fork);

        uint256[] memory transmitterPivateKeys = new uint256[](1);
        transmitterPivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPivateKeys);
    }

    function testInitateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1,
            0,
            1000000,
            100,
            abi.encode(msg.sender)
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (
            bytes32 root,
            bytes32 packetId,
            bytes memory sig
        ) = _getLatestSignature(_a, address(singleCapacitor), _b.chainSlug);
        uint64 capacitorPacketCount = uint64(uint256(packetId));
        polygonL2Switchboard.initateNativeConfirmation(packetId);
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

        hoax(_socketOwner);
        cc_.transmitManager__.setProposeGasLimit(
            remoteChainSlug_,
            _proposeGasLimit
        );

        SocketConfigContext memory scc_ = addPolygonL2Switchboard(
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

    function addPolygonL2Switchboard(
        ChainContext storage cc_,
        uint256 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        polygonL2Switchboard = new PolygonL2Switchboard(
            l1ReceiveGasLimit_,
            initialConfirmationGasLimit_,
            executionOverhead_,
            fxChild_,
            _socketOwner,
            cc_.gasPriceOracle__
        );

        scc_ = registerSwitchbaord(
            cc_,
            _socketOwner,
            address(polygonL2Switchboard),
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
            uint32(capacitorType_),
            _socketOwner
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
        vm.stopPrank();
    }
}
