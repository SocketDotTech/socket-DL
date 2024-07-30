// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "safe-smart-account/common/Enum.sol";

contract MockSafe {
    uint256 public threshold = 1;
    uint256 public nonce = 0;
    address public lastTo;
    uint256 public lastValue;
    bytes public lastData;

    function setThreshold(uint256 _threshold) external {
        threshold = _threshold;
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success) {
        lastTo = to;
        lastValue = value;
        lastData = data;
        return true;
    }

    function getThreshold() external view returns (uint256) {
        return threshold;
    }

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32) {
        return keccak256(abi.encode(to, value, data, operation, _nonce));
    }

    function getLastTransaction()
        external
        view
        returns (address, uint256, bytes memory)
    {
        return (lastTo, lastValue, lastData);
    }
}
