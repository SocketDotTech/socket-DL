// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";
import "../utils/Ownable.sol";

contract Messenger is IPlug, Ownable(msg.sender) {
    // immutables
    ISocket public immutable _socket__;
    uint256 public immutable _localChainSlug;

    bytes32 public _message;
    uint256 public _msgGasLimit;

    bytes32 public constant _PING = keccak256("PING");
    bytes32 public constant _PONG = keccak256("PONG");

    error NoSocketFee();

    constructor(address socket_, uint256 chainSlug_, uint256 msgGasLimit_) {
        _socket__ = ISocket(socket_);
        _localChainSlug = chainSlug_;

        _msgGasLimit = msgGasLimit_;
    }

    receive() external payable {}

    function updateMsgGasLimit(uint256 msgGasLimit_) external onlyOwner {
        _msgGasLimit = msgGasLimit_;
    }

    function removeGas(address payable receiver_) external onlyOwner {
        receiver_.transfer(address(this).balance);
    }

    function sendLocalMessage(bytes32 message_) external {
        _updateMessage(message_);
    }

    function sendRemoteMessage(
        uint32 remoteChainSlug_,
        bytes32 extraParams_,
        bytes32 message_
    ) external payable {
        bytes memory payload = abi.encode(_localChainSlug, message_);
        _outbound(remoteChainSlug_, extraParams_, payload);
    }

    function inbound(
        uint32,
        bytes calldata payload_
    ) external payable override {
        require(msg.sender == address(_socket__), "Counter: Invalid Socket");
        (uint32 remoteChainSlug, bytes32 msgDecoded) = abi.decode(
            payload_,
            (uint32, bytes32)
        );

        _updateMessage(msgDecoded);

        bytes memory newPayload = abi.encode(
            _localChainSlug,
            msgDecoded == _PING ? _PONG : _PING
        );
        _outbound(remoteChainSlug, bytes32(0), newPayload);
    }

    // settings
    function setSocketConfig(
        uint32 remoteChainSlug_,
        address remotePlug_,
        address switchboard_
    ) external onlyOwner {
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

    function _outbound(
        uint32 targetChain_,
        bytes32 extraParams_,
        bytes memory payload_
    ) private {
        uint256 fee = _socket__.getMinFees(
            _msgGasLimit,
            uint256(payload_.length),
            extraParams_,
            targetChain_,
            address(this)
        );
        if (!(address(this).balance >= fee)) revert NoSocketFee();
        _socket__.outbound{value: fee}(
            targetChain_,
            _msgGasLimit,
            extraParams_,
            payload_
        );
    }
}
