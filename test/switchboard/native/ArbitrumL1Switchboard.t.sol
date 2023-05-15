// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/ArbitrumL1Switchboard.sol";

// Goerli -> Arbitrum-Goerli
contract ArbitrumL1SwitchboardTest is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 dynamicFees_ = 100;
    uint256 initiateGasLimit_ = 100;
    uint256 executionOverhead_ = 100;
    address remoteNativeSwitchboard_ =
        0x3f0121d91B5c04B716Ea960790a89b173da7929c;
    address inbox_ = 0x6BEbC4925716945D46F0Ec336D5C2564F419682C;
    address bridge_ = 0xaf4159A80B6Cc41ED517DB1c453d1Ef5C2e4dB72;
    address outbox_ = 0x0000000000000000000000000000000000000000;
    IGasPriceOracle gasPriceOracle_;

    ArbitrumL1Switchboard arbitrumL1Switchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialise();

        _a.chainSlug = uint32(uint256(5));
        _b.chainSlug = uint32(uint256(421613));

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
            inbox_,
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
            inbox_,
            abi.encodeWithSelector(
                arbitrumL1Switchboard.inbox__().createRetryableTicket.selector
            ),
            abi.encode("0x")
        );

        arbitrumL1Switchboard.initiateNativeConfirmation{value: 1e18}(
            packetId,
            10000,
            10000,
            1e16
        );
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

        cc_.transmitManager__.grantRoleWithSlug(
            GAS_LIMIT_UPDATER_ROLE,
            remoteChainSlug_,
            _socketOwner
        );

        cc_.transmitManager__.grantRole(GAS_LIMIT_UPDATER_ROLE, _socketOwner);

        vm.stopPrank();

        bytes32 digest = keccak256(
            abi.encode(
                PROPOSE_GAS_LIMIT_UPDATE_SIG_IDENTIFIER,
                cc_.chainSlug,
                remoteChainSlug_,
                cc_.transmitterNonce,
                _proposeGasLimit
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);
        cc_.transmitManager__.setProposeGasLimit(
            cc_.transmitterNonce++,
            remoteChainSlug_,
            _proposeGasLimit,
            sig
        );

        SocketConfigContext memory scc_ = addArbitrumL1Switchboard(
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

    function addArbitrumL1Switchboard(
        ChainContext storage cc_,
        uint256 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        arbitrumL1Switchboard = new ArbitrumL1Switchboard(
            cc_.chainSlug,
            dynamicFees_,
            initiateGasLimit_,
            executionOverhead_,
            inbox_,
            _socketOwner,
            address(cc_.socket__),
            cc_.gasPriceOracle__,
            bridge_,
            outbox_
        );

        vm.startPrank(_socketOwner);
        arbitrumL1Switchboard.grantRole(GAS_LIMIT_UPDATER_ROLE, _socketOwner);
        arbitrumL1Switchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);

        bytes32 digest = keccak256(
            abi.encode(
                EXECUTION_OVERHEAD_UPDATE_SIG_IDENTIFIER,
                nonce,
                cc_.chainSlug,
                _executionOverhead
            )
        );
        bytes memory sig = _createSignature(digest, _socketOwnerPrivateKey);

        arbitrumL1Switchboard.setExecutionOverhead(
            nonce++,
            _executionOverhead,
            sig
        );
        arbitrumL1Switchboard.updateRemoteNativeSwitchboard(
            remoteNativeSwitchboard_
        );
        vm.stopPrank();

        scc_ = registerSwitchbaord(
            cc_,
            _socketOwner,
            address(arbitrumL1Switchboard),
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

        arbitrumL1Switchboard.grantRole(GOVERNANCE_ROLE, deployer_);
        vm.stopPrank();
    }
}
