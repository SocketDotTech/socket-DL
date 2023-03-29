// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IGasPriceOracle.sol";
import "../../interfaces/ICapacitor.sol";

import "../../utils/AccessControlExtended.sol";
import "../../libraries/SignatureVerifierLib.sol";
import "../../libraries/RescueFundsLib.sol";
import "../../libraries/FeesHelper.sol";

import {GAS_LIMIT_UPDATER_ROLE, GOVERNANCE_ROLE, RESCUE_ROLE, WITHDRAW_ROLE, TRIP_ROLE, UNTRIP_ROLE} from "../../utils/AccessRoles.sol";

abstract contract NativeSwitchboardBase is ISwitchboard, AccessControlExtended {
    IGasPriceOracle public gasPriceOracle__;
    ICapacitor public capacitor__;

    bool public isInitialised;
    bool public tripGlobalFuse;
    uint256 public maxPacketSize;

    uint256 public executionOverhead;
    uint256 public initiateGasLimit;
    address public remoteNativeSwitchboard;
    uint256 public immutable chainSlug;

    // stores the roots received from native bridge
    mapping(bytes32 => bytes32) public packetIdToRoot;
    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    event SwitchboardTripped(bool tripGlobalFuse);
    event ExecutionOverheadSet(uint256 executionOverhead);
    event InitiateGasLimitSet(uint256 gasLimit);
    event CapacitorSet(address capacitor);
    event GasPriceOracleSet(address gasPriceOracle);
    event InitiatedNativeConfirmation(bytes32 packetId);
    event CapacitorRegistered(address capacitor, uint256 maxPacketSize);
    event UpdatedRemoteNativeSwitchboard(address remoteNativeSwitchboard);
    event RootReceived(bytes32 packetId, bytes32 root);

    error TransferFailed();
    error FeesNotEnough();
    error AlreadyInitialised();
    error InvalidSender();
    error NoRootFound();
    error InvalidNonce();

    modifier onlyRemoteSwitchboard() virtual {
        _;
    }

    constructor(
        uint256 chainSlug_,
        uint256 initiateGasLimit_,
        uint256 executionOverhead_,
        IGasPriceOracle gasPriceOracle_
    ) {
        chainSlug = chainSlug_;
        initiateGasLimit = initiateGasLimit_;
        executionOverhead = executionOverhead_;
        gasPriceOracle__ = gasPriceOracle_;
    }

    function _encodeRemoteCall(
        bytes32 packetId_
    ) internal view returns (bytes memory data) {
        uint64 capacitorPacketCount = uint64(uint256(packetId_));
        bytes32 root = capacitor__.getRootByCount(capacitorPacketCount);
        if (root == bytes32(0)) revert NoRootFound();

        data = abi.encodeWithSelector(
            this.receivePacket.selector,
            packetId_,
            root
        );
    }

    function receivePacket(
        bytes32 packetId_,
        bytes32 root_
    ) external onlyRemoteSwitchboard {
        packetIdToRoot[packetId_] = root_;
        emit RootReceived(packetId_, root_);
    }

    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param packetId_ packet id
     */
    function allowPacket(
        bytes32 root_,
        bytes32 packetId_,
        uint32,
        uint256
    ) external view override returns (bool) {
        if (tripGlobalFuse) return false;
        if (packetIdToRoot[packetId_] != root_) return false;

        return true;
    }

    // assumption: natives have 18 decimals
    function payFees(uint32 dstChainSlug_) external payable override {}

    function getMinFees(
        uint32 dstChainSlug_
    )
        external
        view
        override
        returns (uint256 switchboardFee_, uint256 verificationFee_)
    {
        return _calculateMinFees(dstChainSlug_);
    }

    function _calculateMinFees(
        uint32 dstChainSlug_
    )
        internal
        view
        returns (uint256 switchboardFee_, uint256 verificationFee_)
    {
        (uint256 sourceGasPrice, uint256 dstRelativeGasPrice) = gasPriceOracle__
            .getGasPrices(dstChainSlug_);

        switchboardFee_ =
            _getMinSwitchboardFees(
                dstChainSlug_,
                dstRelativeGasPrice,
                sourceGasPrice
            ) /
            maxPacketSize;

        verificationFee_ = executionOverhead * dstRelativeGasPrice;
    }

    function _getMinSwitchboardFees(
        uint256 dstChainSlug_,
        uint256 dstRelativeGasPrice_,
        uint256 sourceGasPrice_
    ) internal view virtual returns (uint256);

    /**
     * @notice set capacitor address and packet size
     * @param capacitor_ capacitor address
     * @param maxPacketSize_ max messages allowed in one packet
     */
    function registerCapacitor(
        address capacitor_,
        uint256 maxPacketSize_
    ) external override {
        if (isInitialised) revert AlreadyInitialised();

        isInitialised = true;
        maxPacketSize = maxPacketSize_;
        capacitor__ = ICapacitor(capacitor_);

        emit CapacitorRegistered(capacitor_, maxPacketSize_);
    }

    /**
     * @notice pause execution
     */
    function tripGlobal(uint256 nonce_, bytes memory signature_) external {
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
            // it includes trip status at the end
            keccak256(abi.encode("TRIP", chainSlug, nonce_, true)),
            signature_
        );

        if (!_hasRole(TRIP_ROLE, watcher)) revert NoPermit(TRIP_ROLE);

        uint256 nonce = nextNonce[watcher]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripGlobalFuse = true;
        emit SwitchboardTripped(true);
    }

    /**
     * @notice unpause execution
     */
    function untrip(uint256 nonce_, bytes memory signature_) external {
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
            // it includes trip status at the end
            keccak256(abi.encode("UNTRIP", chainSlug, nonce_, false)),
            signature_
        );

        if (!_hasRole(UNTRIP_ROLE, watcher)) revert NoPermit(UNTRIP_ROLE);
        uint256 nonce = nextNonce[watcher]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripGlobalFuse = false;
        emit SwitchboardTripped(false);
    }

    /**
     * @notice updates execution overhead
     * @param executionOverhead_ new execution overhead cost
     */
    function setExecutionOverhead(
        uint256 nonce_,
        uint256 executionOverhead_,
        bytes memory signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "EXECUTION_OVERHEAD_UPDATE",
                    chainSlug,
                    nonce_,
                    executionOverhead_
                )
            ),
            signature_
        );

        if (!_hasRole(GAS_LIMIT_UPDATER_ROLE, gasLimitUpdater))
            revert NoPermit(GAS_LIMIT_UPDATER_ROLE);
        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        executionOverhead = executionOverhead_;
        emit ExecutionOverheadSet(executionOverhead_);
    }

    /**
     * @notice updates initiateGasLimit
     * @param gasLimit_ new gas limit for initiateGasLimit
     */
    function setInitiateGasLimit(
        uint256 nonce_,
        uint256 gasLimit_,
        bytes memory signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "INITIAL_CONFIRMATION_GAS_LIMIT_UPDATE",
                    chainSlug,
                    nonce_,
                    gasLimit_
                )
            ),
            signature_
        );

        if (!_hasRole(GAS_LIMIT_UPDATER_ROLE, gasLimitUpdater))
            revert NoPermit(GAS_LIMIT_UPDATER_ROLE);
        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        initiateGasLimit = gasLimit_;
        emit InitiateGasLimitSet(gasLimit_);
    }

    /**
     * @notice updates gasPriceOracle_ address
     * @param gasPriceOracle_ new gasPriceOracle_
     */
    function setGasPriceOracle(
        address gasPriceOracle_
    ) external onlyRole(GOVERNANCE_ROLE) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        emit GasPriceOracleSet(gasPriceOracle_);
    }

    function updateRemoteNativeSwitchboard(
        address remoteNativeSwitchboard_
    ) external onlyRole(GOVERNANCE_ROLE) {
        remoteNativeSwitchboard = remoteNativeSwitchboard_;
        emit UpdatedRemoteNativeSwitchboard(remoteNativeSwitchboard_);
    }

    function withdrawFees(address account_) external onlyRole(WITHDRAW_ROLE) {
        FeesHelper.withdrawFees(account_);
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
