// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";
import "../interfaces/ITransmitManager.sol";
import "../interfaces/ISwitchboard.sol";
import "../interfaces/IExecutionManager.sol";
import "../utils/Ownable.sol";

contract Messenger is IPlug, Ownable(msg.sender) {
    // immutables
    ISocket public immutable _socket__;
    uint256 public immutable _localChainSlug;
    ITransmitManager public _transmitManager__;
    ISwitchboard public _switchboard__;
    IExecutionManager public _executionManager__;

    bytes32 public _message;
    uint256 public msgGasLimit;

    bytes32 public constant _PING = keccak256("PING");
    bytes32 public constant _PONG = keccak256("PONG");

    uint256 public constant SOCKET_FEE = 0.001 ether;

    error NoSocketFee();

    constructor(address socket_, uint256 chainSlug_, uint256 msgGasLimit_) {
        _socket__ = ISocket(socket_);
        _transmitManager__ = ISocket(socket_)._transmitManager__();
        _executionManager__ = ISocket(socket_)._executionManager__();
        _localChainSlug = chainSlug_;

        msgGasLimit = msgGasLimit_;
    }

    receive() external payable {}

    function removeGas(address payable receiver_) external onlyOwner {
        receiver_.transfer(address(this).balance);
    }

    function sendLocalMessage(bytes32 message_) external {
        _updateMessage(message_);
    }

    function sendRemoteMessage(
        uint256 remoteChainSlug_,
        bytes32 message_
    ) external payable {
        bytes memory payload = abi.encode(_localChainSlug, message_);
        _outbound(remoteChainSlug_, payload);
    }

    function inbound(
        uint256,
        bytes calldata payload_
    ) external payable override {
        require(msg.sender == address(_socket__), "Counter: Invalid Socket");
        (uint256 remoteChainSlug, bytes32 msgDecoded) = abi.decode(
            payload_,
            (uint256, bytes32)
        );

        _updateMessage(msgDecoded);

        bytes memory newPayload = abi.encode(
            _localChainSlug,
            msgDecoded == _PING ? _PONG : _PING
        );
        _outbound(remoteChainSlug, newPayload);
    }

    // settings
    function setSocketConfig(
        uint256 remoteChainSlug_,
        address remotePlug_,
        address switchboard_
    ) external onlyOwner {
        _switchboard__ = ISwitchboard(switchboard_);
        _socket__.connect(
            remoteChainSlug_,
            remotePlug_,
            switchboard_,
            switchboard_
        );
    }

    function message() external view returns (bytes32) {
        return _message;
    }

    function _updateMessage(bytes32 message_) private {
        _message = message_;
    }

    function _outbound(uint256 targetChain_, bytes memory payload_) private {
        (uint256 switchboardFee, uint256 verificationFee) = _switchboard__
            .getMinFees(targetChain_);
        uint256 fee = switchboardFee +
            verificationFee +
            _transmitManager__.getMinFees(targetChain_) +
            _executionManager__.getMinFees(msgGasLimit, targetChain_);
        if (!(address(this).balance >= fee)) revert NoSocketFee();
        _socket__.outbound{value: fee}(targetChain_, msgGasLimit, payload_);
    }
}
