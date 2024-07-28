// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../libraries/RescueFundsLib.sol";

import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import "safe-smart-account/common/Enum.sol";

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
    ISafe public safe;
    mapping(bytes32 => bytes) public signatures;

    uint256 public safeTxGas = 0;
    uint256 public baseGas = 0;
    uint256 public gasPrice = 0;
    address public gasToken = address(0);
    address public refundReceiver = address(0);
    Enum.Operation public operation = Enum.Operation.Call;

    event AddedTxHash(
        bytes32 txHash,
        address to,
        uint256 value,
        bytes data,
        uint256 nonce
    );

    event ConstantsUpdated(
        uint256 safeTxGas_,
        uint256 baseGas_,
        uint256 gasPrice_,
        address gasToken_,
        address refundReceiver_
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
        address to_,
        uint256 nonce_,
        uint256 value_,
        bytes calldata data_,
        bytes memory signature_
    ) external {
        bytes32 txHash = keccak256(
            abi.encode(to_, value_, data_, operation, nonce_)
        );

        bytes memory signs = abi.encodePacked(signatures[txHash], signature_);
        signatures[txHash] = signs;
        uint256 threshold = safe.getThreshold();

        if (signs.length >= threshold * 65)
            safe.execTransaction(
                to_,
                value_,
                data_,
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                payable(refundReceiver),
                signs
            );

        emit AddedTxHash(txHash, to_, value_, data_, nonce_);
    }

    /**
     * @notice Update public constants
     */
    function updateConstants(
        uint256 safeTxGas_,
        uint256 baseGas_,
        uint256 gasPrice_,
        address gasToken_,
        address refundReceiver_
    ) external onlyOwner {
        safeTxGas = safeTxGas_;
        baseGas = baseGas_;
        gasPrice = gasPrice_;
        gasToken = gasToken_;
        refundReceiver = refundReceiver_;

        emit ConstantsUpdated(
            safeTxGas_,
            baseGas_,
            gasPrice_,
            gasToken_,
            refundReceiver_
        );
    }

    /**
     * @notice Update public constants
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
