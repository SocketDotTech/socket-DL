// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.20;

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

    constructor(address socket_) {
        socket = socket_;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "can only be called by owner");
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
        require(msg.sender == socket, "Counter: Invalid Socket");
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
        require(counter > amount_, "CounterMock: Subtraction Overflow");
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
     * @notice Rescues funds from a contract that has lost access to them.
     * @param token_ The address of the token contract.
     * @param userAddress_ The address of the user who lost access to the funds.
     * @param amount_ The amount of tokens to be rescued.
     */
    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
