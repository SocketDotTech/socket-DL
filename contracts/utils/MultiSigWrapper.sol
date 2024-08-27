// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../libraries/RescueFundsLib.sol";

import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import "safe-smart-account/common/Enum.sol";
import "solady/utils/LibSort.sol";

interface ISafe {
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
    ) external payable returns (bool success);

    function getThreshold() external view returns (uint256);

    function nonce() external view returns (uint256);

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
    ) external view returns (bytes32);
}

/**
 * @title MultiSigWrapper
 */
contract MultiSigWrapper is AccessControl {
    using LibSort for address;

    ISafe public safe;
    mapping(bytes32 => address[]) public owners;
    mapping(address => uint256) public lastNonce;

    mapping(bytes32 => mapping(address => bytes)) public signatures;
    struct GasParams {
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
    }

    event AddedTxHash(
        bytes32 txHash,
        address to,
        uint256 value,
        bytes data,
        uint256 nonce
    );

    event SafeUpdated(address safe_);

    /**
     * @notice initializes and grants RESCUE_ROLE to owner.
     * @param owner_ The address of the owner of the contract.
     * @param safe_ The address of the safe contract.
     */
    constructor(address owner_, address safe_) AccessControl(owner_) {
        safe = ISafe(safe_);
        _grantRole(RESCUE_ROLE, owner_);
    }

    function storeOrRelaySignatures(
        address from_,
        address to_,
        uint256 nonce_,
        uint256 value_,
        bytes calldata data_,
        bytes memory signature_
    ) external {
        GasParams memory gasParams;

        _signOrRelay(
            from_,
            to_,
            nonce_,
            value_,
            Enum.Operation.Call,
            gasParams,
            data_,
            signature_
        );
    }

    function storeOrRelaySignaturesWithOverrides(
        address from_,
        address to_,
        uint256 nonce_,
        uint256 value_,
        Enum.Operation operation_,
        GasParams calldata gasParams_,
        bytes calldata data_,
        bytes memory signature_
    ) external {
        _signOrRelay(
            from_,
            to_,
            nonce_,
            value_,
            operation_,
            gasParams_,
            data_,
            signature_
        );
    }

    function _signOrRelay(
        address from_,
        address to_,
        uint256 nonce_,
        uint256 value_,
        Enum.Operation operation_,
        GasParams memory gasParams_,
        bytes calldata data_,
        bytes memory signature_
    ) internal {
        uint256 threshold = safe.getThreshold();
        lastNonce[to_] = nonce_;

        if (threshold == 1)
            return
                _relay(to_, value_, operation_, gasParams_, data_, signature_);

        bytes32 txHash = keccak256(
            abi.encode(
                to_,
                value_,
                data_,
                operation_,
                nonce_,
                gasParams_.gasPrice
            )
        );
        uint256 totalSignatures = _storeSignatures(txHash, from_, signature_);

        if (totalSignatures >= threshold)
            _relay(
                to_,
                value_,
                operation_,
                gasParams_,
                data_,
                _getSignatures(txHash)
            );

        emit AddedTxHash(txHash, to_, value_, data_, nonce_);
    }

    function _relay(
        address to_,
        uint256 value_,
        Enum.Operation operation_,
        GasParams memory gasParams_,
        bytes calldata data_,
        bytes memory signatures_
    ) internal {
        safe.execTransaction(
            to_,
            value_,
            data_,
            operation_,
            gasParams_.safeTxGas,
            gasParams_.baseGas,
            gasParams_.gasPrice,
            gasParams_.gasToken,
            payable(gasParams_.refundReceiver),
            signatures_
        );
    }

    function _storeSignatures(
        bytes32 txHash_,
        address from_,
        bytes memory signature_
    ) internal returns (uint256 totalSignatures) {
        owners[txHash_].push(from_);
        signatures[txHash_][from_] = signature_;
        totalSignatures = owners[txHash_].length;
    }

    function _getSignatures(
        bytes32 txHash_
    ) internal view returns (bytes memory signature) {
        address[] memory txOwners = owners[txHash_];
        LibSort.insertionSort(txOwners);
        uint256 len = txOwners.length;

        for (uint256 index = 0; index < len; index++) {
            signature = abi.encodePacked(
                signature,
                signatures[txHash_][txOwners[index]]
            );
        }
    }

    /**
     * @notice Update safe address
     */
    function updateSafe(address safe_) external onlyOwner {
        safe = ISafe(safe_);
        emit SafeUpdated(safe_);
    }

    function getNonce() external view returns (uint256) {
        return safe.nonce();
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
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, rescueTo_, amount_);
    }
}
