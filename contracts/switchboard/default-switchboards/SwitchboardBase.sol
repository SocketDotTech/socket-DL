// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/ISwitchboard.sol";
import "../../interfaces/IGasPriceOracle.sol";
import "../../utils/AccessControlExtended.sol";

import "../../libraries/SignatureVerifierLib.sol";
import "../../libraries/RescueFundsLib.sol";
import "../../libraries/FeesHelper.sol";

import {GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, GAS_LIMIT_UPDATER_ROLE} from "../../utils/AccessRoles.sol";

abstract contract SwitchboardBase is ISwitchboard, AccessControlExtended {
    IGasPriceOracle public gasPriceOracle__;

    bool public tripGlobalFuse;
    address public socket;
    uint256 public immutable chainSlug;
    uint256 public immutable timeoutInSeconds;

    mapping(uint256 => bool) public isInitialised;
    mapping(uint256 => uint256) public maxPacketSize;

    mapping(uint256 => uint256) public executionOverhead;

    // sourceChain => isPaused
    mapping(uint256 => bool) public tripSinglePath;

    // watcher => nextNonce
    mapping(address => uint256) public nextNonce;

    event PathTripped(uint256 srcChainSlug, bool tripSinglePath);
    event SwitchboardTripped(bool tripGlobalFuse);
    event ExecutionOverheadSet(uint256 dstChainSlug, uint256 executionOverhead);
    event GasPriceOracleSet(address gasPriceOracle);
    event CapacitorRegistered(
        uint256 siblingChainSlug,
        address capacitor,
        uint256 maxPacketSize
    );

    error AlreadyInitialised();
    error InvalidNonce();
    error OnlySocket();

    constructor(
        address gasPriceOracle_,
        address socket_,
        uint256 chainSlug_,
        uint256 timeoutInSeconds_
    ) {
        gasPriceOracle__ = IGasPriceOracle(gasPriceOracle_);
        socket = socket_;
        chainSlug = chainSlug_;
        timeoutInSeconds = timeoutInSeconds_;
    }

    function payFees(uint32 dstChainSlug_) external payable override {}

    function getMinFees(
        uint32 dstChainSlug_
    ) external view override returns (uint256, uint256) {
        return _calculateMinFees(dstChainSlug_);
    }

    function _calculateMinFees(
        uint32 dstChainSlug_
    ) internal view returns (uint256 switchboardFee, uint256 verificationFee) {
        uint256 dstRelativeGasPrice = gasPriceOracle__.relativeGasPrice(
            dstChainSlug_
        );

        switchboardFee =
            _getMinSwitchboardFees(dstChainSlug_, dstRelativeGasPrice) /
            maxPacketSize[dstChainSlug_];
        verificationFee =
            executionOverhead[dstChainSlug_] *
            dstRelativeGasPrice;
    }

    function _getMinSwitchboardFees(
        uint256 dstChainSlug_,
        uint256 dstRelativeGasPrice_
    ) internal view virtual returns (uint256);

    /**
     * @notice set capacitor address and packet size
     * @param capacitor_ capacitor address
     * @param maxPacketSize_ max messages allowed in one packet
     */
    function registerCapacitor(
        uint256 siblingChainSlug_,
        address capacitor_,
        uint256 maxPacketSize_
    ) external override {
        if (msg.sender != socket) revert OnlySocket();
        if (isInitialised[siblingChainSlug_]) revert AlreadyInitialised();

        isInitialised[siblingChainSlug_] = true;
        maxPacketSize[siblingChainSlug_] = maxPacketSize_;
        emit CapacitorRegistered(siblingChainSlug_, capacitor_, maxPacketSize_);
    }

    /**
     * @notice pause a path
     */
    function tripPath(
        uint256 nonce_,
        uint256 srcChainSlug_,
        bytes memory signature_
    ) external {
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
            // it includes trip status at the end
            keccak256(
                abi.encode("TRIP_PATH", srcChainSlug_, chainSlug, nonce_, true)
            ),
            signature_
        );

        if (!_hasRole("TRIP_ROLE", srcChainSlug_, watcher))
            revert NoPermit("TRIP_ROLE");
        uint256 nonce = nextNonce[watcher]++;
        if (nonce_ != nonce) revert InvalidNonce();

        //source chain based tripping
        tripSinglePath[srcChainSlug_] = true;
        emit PathTripped(srcChainSlug_, true);
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

        if (!_hasRole("TRIP_ROLE", watcher)) revert NoPermit("TRIP_ROLE");
        uint256 nonce = nextNonce[watcher]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripGlobalFuse = true;
        emit SwitchboardTripped(true);
    }

    /**
     * @notice unpause a path
     */
    function untripPath(
        uint256 nonce_,
        uint256 srcChainSlug_,
        bytes memory signature_
    ) external {
        address watcher = SignatureVerifierLib.recoverSignerFromDigest(
            // it includes trip status at the end
            keccak256(
                abi.encode(
                    "UNTRIP_PATH",
                    chainSlug,
                    srcChainSlug_,
                    nonce_,
                    false
                )
            ),
            signature_
        );

        if (!_hasRole("UNTRIP_ROLE", srcChainSlug_, watcher))
            revert NoPermit("UNTRIP_ROLE");
        uint256 nonce = nextNonce[watcher]++;
        if (nonce_ != nonce) revert InvalidNonce();

        tripSinglePath[srcChainSlug_] = false;
        emit PathTripped(srcChainSlug_, false);
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

        if (!_hasRole("UNTRIP_ROLE", watcher)) revert NoPermit("UNTRIP_ROLE");
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
        uint256 dstChainSlug_,
        uint256 executionOverhead_,
        bytes memory signature_
    ) external {
        address gasLimitUpdater = SignatureVerifierLib.recoverSignerFromDigest(
            keccak256(
                abi.encode(
                    "EXECUTION_OVERHEAD_UPDATE",
                    nonce_,
                    chainSlug,
                    dstChainSlug_,
                    executionOverhead_
                )
            ),
            signature_
        );

        if (!_hasRole("GAS_LIMIT_UPDATER_ROLE", dstChainSlug_, gasLimitUpdater))
            revert NoPermit("GAS_LIMIT_UPDATER_ROLE");
        uint256 nonce = nextNonce[gasLimitUpdater]++;
        if (nonce_ != nonce) revert InvalidNonce();

        executionOverhead[dstChainSlug_] = executionOverhead_;
        emit ExecutionOverheadSet(dstChainSlug_, executionOverhead_);
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
