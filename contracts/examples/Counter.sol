// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../interfaces/IPlug.sol";
import "../interfaces/ISocket.sol";
import "../libraries/RescueFundsLib.sol";

contract Counter is IPlug {
    // immutables
    address public immutable socket;

    address public owner;

    // application state
    uint256 public counter;

    // application ops
    bytes32 public constant OP_ADD = keccak256("OP_ADD");
    bytes32 public constant OP_SUB = keccak256("OP_SUB");

    error OnlyOwner();
    error OnlySocket();
    error InvalidAmount();

    constructor(address socket_) {
        socket = socket_;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    function localAddOperation(uint256 amount_) external {
        _addOperation(amount_);
    }

    function localSubOperation(uint256 amount_) external {
        _subOperation(amount_);
    }

    function remoteAddOperation(
        uint32 chainSlug_,
        uint256 amount_,
        uint256 minMsgGasLimit_,
        bytes32 executionParams_,
        bytes32 transmissionParams_
    ) external payable {
        bytes memory payload = abi.encode(OP_ADD, amount_, msg.sender);

        _outbound(
            chainSlug_,
            minMsgGasLimit_,
            executionParams_,
            transmissionParams_,
            payload
        );
    }

    function remoteSubOperation(
        uint32 chainSlug_,
        uint256 amount_,
        uint256 minMsgGasLimit_,
        bytes32 executionParams_,
        bytes32 transmissionParams_
    ) external payable {
        bytes memory payload = abi.encode(OP_SUB, amount_, msg.sender);
        _outbound(
            chainSlug_,
            minMsgGasLimit_,
            executionParams_,
            transmissionParams_,
            payload
        );
    }

    function inbound(
        uint32,
        bytes calldata payload_
    ) external payable override {
        if (msg.sender != socket) revert OnlySocket();
        (bytes32 operationType, uint256 amount, ) = abi.decode(
            payload_,
            (bytes32, uint256, address)
        );

        if (operationType == OP_ADD) {
            _addOperation(amount);
        } else if (operationType == OP_SUB) {
            _subOperation(amount);
        } else {
            revert("CounterMock: Invalid Operation");
        }
    }

    function _outbound(
        uint32 targetChain_,
        uint256 minMsgGasLimit_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        bytes memory payload_
    ) private {
        ISocket(socket).outbound{value: msg.value}(
            targetChain_,
            minMsgGasLimit_,
            executionParams_,
            transmissionParams_,
            payload_
        );
    }

    //
    // base ops
    //
    function _addOperation(uint256 amount_) private {
        counter += amount_;
    }

    function _subOperation(uint256 amount_) private {
        if (counter < amount_) revert InvalidAmount();
        counter -= amount_;
    }

    // settings
    function setSocketConfig(
        uint32 remoteChainSlug_,
        address remotePlug_,
        address switchboard_
    ) external onlyOwner {
        ISocket(socket).connect(
            remoteChainSlug_,
            remotePlug_,
            switchboard_,
            switchboard_
        );
    }

    function setupComplete() external {
        owner = address(0);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake.
     * @param token_ The address of the token contract.
     * @param rescueTo_ The address where rescued tokens need to be sent.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, rescueTo_, amount_);
    }
}
