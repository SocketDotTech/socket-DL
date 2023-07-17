// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";
import "../utils/Ownable.sol";

contract Messenger is IPlug, Ownable(msg.sender) {
    // immutables
    ISocket public immutable _socket__;
    uint256 public immutable _localChainSlug;

    bytes32 public _message;
    uint256 public _minMsgGasLimit;

    bytes32 public constant _PING = keccak256("PING");
    bytes32 public constant _PONG = keccak256("PONG");

    error NoSocketFee();
    error NotSocket();

    constructor(address socket_, uint256 chainSlug_, uint256 minMsgGasLimit_) {
        _socket__ = ISocket(socket_);
        _localChainSlug = chainSlug_;

        _minMsgGasLimit = minMsgGasLimit_;
    }

    receive() external payable {}

    function updateMsgGasLimit(uint256 minMsgGasLimit_) external onlyOwner {
        _minMsgGasLimit = minMsgGasLimit_;
    }

    function removeGas(address payable receiver_) external onlyOwner {
        receiver_.transfer(address(this).balance);
    }

    function sendLocalMessage(bytes32 message_) external {
        _updateMessage(message_);
    }

    function sendRemoteMessage(
        uint32 remoteChainSlug_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        bytes32 message_
    ) external payable {
        bytes memory payload = abi.encode(_localChainSlug, message_);
        _outbound(
            remoteChainSlug_,
            executionParams_,
            transmissionParams_,
            payload
        );
    }

    function inbound(
        uint32,
        bytes calldata payload_
    ) external payable override {
        if (msg.sender != address(_socket__)) revert NotSocket();
        (uint32 remoteChainSlug, bytes32 msgDecoded) = abi.decode(
            payload_,
            (uint32, bytes32)
        );

        _updateMessage(msgDecoded);

        bytes memory newPayload = abi.encode(
            _localChainSlug,
            msgDecoded == _PING ? _PONG : _PING
        );
        _outbound(remoteChainSlug, bytes32(0), bytes32(0), newPayload);
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
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        bytes memory payload_
    ) private {
        uint256 fee = _socket__.getMinFees(
            _minMsgGasLimit,
            uint256(payload_.length),
            executionParams_,
            transmissionParams_,
            targetChain_,
            address(this)
        );
        if (!(address(this).balance >= fee)) revert NoSocketFee();
        _socket__.outbound{value: fee}(
            targetChain_,
            _minMsgGasLimit,
            executionParams_,
            transmissionParams_,
            payload_
        );
    }
}
