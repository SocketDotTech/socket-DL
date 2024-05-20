// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../../Setup.t.sol";
import "../../../contracts/switchboard/native/OptimismSwitchboard.sol";

// sepolia -> Optimism-sepolia
// RemoteNativeSwitchBoard i.e SwitchBoard on sepolia (11155111) is:0xEDF6dB2f3BC8deE014762e0141EE4CA19d685dBd
contract OptimismSwitchboardL2L1Test is Setup {
    bytes32[] roots;
    uint256 nonce;

    uint256 receiveGasLimit_ = 100000;
    uint256 confirmGasLimit_ = 100000;
    uint256 initiateGasLimit_ = 100000;
    uint256 executionOverhead_ = 100000;
    address crossDomainManagerAddress_ =
        0x4200000000000000000000000000000000000007;
    address sepoliaCrossDomainManagerAddress_ =
        0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;

    OptimismSwitchboard optimismSwitchboard;
    ICapacitor singleCapacitor;

    function setUp() external {
        initialize();

        _a.chainSlug = uint32(uint256(11155420));
        _b.chainSlug = uint32(uint256(11155111));

        uint256 fork = vm.createFork(vm.envString("OPTIMISM_SEPOLIA_RPC"));
        vm.selectFork(fork);

        uint256[] memory transmitterPrivateKeys = new uint256[](1);
        transmitterPrivateKeys[0] = _transmitterPrivateKey;

        _chainSetup(transmitterPrivateKeys);
    }

    function testInitiateNativeConfirmation() public {
        address socketAddress = address(_a.socket__);

        vm.startPrank(socketAddress);

        ISocket.MessageDetails memory messageDetails;
        messageDetails.msgId = 0;
        messageDetails.minMsgGasLimit = 1000000;
        messageDetails.executionFee = 100;
        messageDetails.payload = abi.encode(msg.sender);

        bytes32 packedMessage = _a.hasher__.packMessage(
            _a.chainSlug,
            msg.sender,
            _b.chainSlug,
            address(1),
            messageDetails
        );

        singleCapacitor.addPackedMessage(packedMessage);

        (, bytes32 packetId, ) = _getLatestSignature(
            address(singleCapacitor),
            _a.chainSlug,
            _b.chainSlug
        );
        // optimismSwitchboard.initiateNativeConfirmation(packetId);
        vm.stopPrank();
    }

    function testReceivePacket() public {
        bytes32 packetId = bytes32(uint256(100));
        bytes32 root = bytes32(uint256(200));

        // call is not from crossDomainManagerAddress_
        vm.expectRevert(NativeSwitchboardBase.InvalidSender.selector);
        optimismSwitchboard.receivePacket(packetId, root);

        // call from wrong remoteNativeSwitchboard
        vm.mockCall(
            crossDomainManagerAddress_,
            abi.encodeWithSelector(
                optimismSwitchboard
                    .crossDomainMessenger__()
                    .xDomainMessageSender
                    .selector
            ),
            abi.encode(address(1))
        );

        hoax(crossDomainManagerAddress_);
        vm.expectRevert(NativeSwitchboardBase.InvalidSender.selector);
        optimismSwitchboard.receivePacket(packetId, root);

        // correct call
        vm.mockCall(
            crossDomainManagerAddress_,
            abi.encodeWithSelector(
                optimismSwitchboard
                    .crossDomainMessenger__()
                    .xDomainMessageSender
                    .selector
            ),
            abi.encode(optimismSwitchboard.remoteNativeSwitchboard())
        );

        vm.startPrank(crossDomainManagerAddress_);
        optimismSwitchboard.receivePacket(packetId, root);
        vm.stopPrank();
    }

    function testUpdateReceiveGasLimit() public {
        uint256 receiveGasLimit = 1000;
        assertEq(optimismSwitchboard.receiveGasLimit(), receiveGasLimit_);

        hoax(_raju);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.NoPermit.selector,
                GOVERNANCE_ROLE
            )
        );
        optimismSwitchboard.updateReceiveGasLimit(receiveGasLimit);

        hoax(_socketOwner);
        optimismSwitchboard.updateReceiveGasLimit(receiveGasLimit);

        assertEq(optimismSwitchboard.receiveGasLimit(), receiveGasLimit);
    }

    function _chainSetup(uint256[] memory transmitterPrivateKeys_) internal {
        _deployContractsOnSingleChain(
            _a,
            _b.chainSlug,
            isExecutionOpen,
            transmitterPrivateKeys_
        );

        SocketConfigContext memory scc_ = addOptimismSwitchboard(
            _a,
            _b.chainSlug,
            _capacitorType
        );
        _a.configs__.push(scc_);
    }

    function addOptimismSwitchboard(
        ChainContext storage cc_,
        uint32 remoteChainSlug_,
        uint256 capacitorType_
    ) internal returns (SocketConfigContext memory scc_) {
        vm.startPrank(_socketOwner);

        optimismSwitchboard = new OptimismSwitchboard(
            cc_.chainSlug,
            receiveGasLimit_,
            _socketOwner,
            address(cc_.socket__),
            crossDomainManagerAddress_,
            cc_.sigVerifier__
        );

        optimismSwitchboard.grantRole(GOVERNANCE_ROLE, _socketOwner);
        vm.stopPrank();

        scc_ = _registerSwitchboardForSibling(
            cc_,
            _socketOwner,
            address(optimismSwitchboard),
            0,
            remoteChainSlug_,
            capacitorType_,
            siblingSwitchboard
        );
        singleCapacitor = scc_.capacitor__;
    }
}
