// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../../interfaces/native-bridge/IFxMessageProcessor.sol";
import {NativeBridgeNotary} from "./NativeBridgeNotary.sol";

contract PolygonReceiver is NativeBridgeNotary, IFxMessageProcessor {
    bool public isL2;

    error UnauthorizedChildOrigin();
    error UnauthorizedRootOrigin();

    /**
     * @dev Emitted when the FxRoot Sender is updated
     * @param oldFxRootSender The address of the old FxRootSender
     * @param newFxRootSender The address of the new FxRootSender
     **/
    event FxRootSenderUpdate(address oldFxRootSender, address newFxRootSender);

    /**
     * @dev Emitted when the FxChild is updated
     * @param oldFxChild The address of the old FxChild
     * @param newFxChild The address of the new FxChild
     **/
    event FxChildUpdate(address oldFxChild, address newFxChild);

    // Address of the FxRoot Sender, sending the cross-chain transaction from Ethereum
    address private _fxRootSender;
    // Address of the FxChild, in charge of redirecting cross-chain transactions in Polygon
    address private _fxChild;

    /**
     * @dev Only FxChild can call functions marked by this modifier.
     **/
    modifier onlyFxChild() {
        if (msg.sender != _fxChild) revert UnauthorizedChildOrigin();
        _;
    }

    modifier onlyRemoteAccumulator() override {
        _;
    }

    /**
     * @dev Constructor
     *
     * @param fxRootSender The address of the transaction sender in FxRoot
     * @param fxChild The address of the FxChild
     */
    constructor(
        address fxRootSender,
        address fxChild,
        address signatureVerifier_,
        uint32 chainSlug_,
        address remoteTarget_
    ) NativeBridgeNotary(signatureVerifier_, chainSlug_, remoteTarget_) {
        isL2 = (block.chainid == 137 || block.chainid == 80001) ? true : false;
        _fxRootSender = fxRootSender;
        _fxChild = fxChild;
    }

    /// @inheritdoc IFxMessageProcessor
    function processMessageFromRoot(
        uint256,
        address rootMessageSender,
        bytes calldata data
    ) external override onlyFxChild {
        if (rootMessageSender != _fxRootSender) revert UnauthorizedRootOrigin();

        uint256 packetId;
        bytes32 root;

        (packetId, root, ) = abi.decode(data, (uint256, bytes32, bytes));
        _attest(packetId, root);
    }

    /**
     * @notice Update the address of the FxRoot Sender
     * @param fxRootSender The address of the new FxRootSender
     **/
    function updateFxRootSender(address fxRootSender) external onlyOwner {
        emit FxRootSenderUpdate(_fxRootSender, fxRootSender);
        _fxRootSender = fxRootSender;
    }

    /**
     * @notice Update the address of the FxChild
     * @param fxChild The address of the new FxChild
     **/
    function updateFxChild(address fxChild) external onlyOwner {
        emit FxChildUpdate(_fxChild, fxChild);
        _fxChild = fxChild;
    }

    /**
     * @notice Returns the address of the FxRoot Sender
     * @return The address of the FxRootSender
     **/
    function getFxRootSender() external view returns (address) {
        return _fxRootSender;
    }

    /**
     * @notice Returns the address of the FxChild
     * @return fxChild The address of FxChild
     **/
    function getFxChild() external view returns (address) {
        return _fxChild;
    }
}
