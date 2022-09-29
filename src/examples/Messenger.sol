// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";

contract Messenger is IPlug {
    // immutables
    address private immutable _socket;
    uint256 private immutable _chainId;

    address private _owner;
    bytes32 private _message;
    uint256 public msgGasLimit;

    bytes32 private constant _PING = keccak256("PING");
    bytes32 private constant _PONG = keccak256("PONG");

    constructor(
        address socket_,
        uint256 chainId_,
        uint256 msgGasLimit_
    ) {
        _socket = socket_;
        _chainId = chainId_;
        _owner = msg.sender;

        msgGasLimit = msgGasLimit_;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "can only be called by owner");
        _;
    }

    function sendLocalMessage(bytes32 message_) external {
        _updateMessage(message_);
    }

    function sendRemoteMessage(uint256 destChainId_, bytes32 message_)
        external
        payable
    {
        bytes memory payload = abi.encode(_chainId, message_);
        _outbound(destChainId_, payload);
    }

    function inbound(bytes calldata payload_) external payable override {
        require(msg.sender == _socket, "Counter: Invalid Socket");
        (uint256 srcChainId, bytes32 msgDecoded) = abi.decode(
            payload_,
            (uint256, bytes32)
        );

        _updateMessage(msgDecoded);

        bytes memory newPayload = abi.encode(
            _chainId,
            msgDecoded == _PING ? _PONG : _PING
        );
        _outbound(srcChainId, newPayload);
    }

    // settings
    function setSocketConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_,
        address deaccum_,
        address verifier_
    ) external onlyOwner {
        ISocket(_socket).setInboundConfig(
            remoteChainId_,
            remotePlug_,
            deaccum_,
            verifier_
        );
        ISocket(_socket).setOutboundConfig(remoteChainId_, remotePlug_, accum_);
    }

    function message() external view returns (bytes32) {
        return _message;
    }

    function _updateMessage(bytes32 message_) private {
        _message = message_;
    }

    function _outbound(uint256 targetChain_, bytes memory payload_) private {
        ISocket(_socket).outbound{value: msg.value}(
            targetChain_,
            msgGasLimit,
            payload_
        );
    }
}
