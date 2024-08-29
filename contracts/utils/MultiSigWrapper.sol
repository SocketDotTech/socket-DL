// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "../libraries/RescueFundsLib.sol";

import "../utils/AccessControl.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import "solady/utils/LibSort.sol";

import {ISafe, Enum} from "./SafeL2.sol";

/**
 * @title MultiSigWrapper
 * @dev if someone directly interacts with safe and increases the nonce, the owners
 * will have to resubmit the pending txs with updated nonce here again.
 * For new transactions, it should be handled off-chain.
 */
contract MultiSigWrapper is AccessControl {
    using LibSort for address;

    ISafe public safe;
    // owners => last nonce used
    mapping(address => uint256) public lastNonce;
    // data hash => nonce => owners list (as we can have same data for multiple nonces)
    mapping(bytes32 => mapping(uint256 => address[])) public owners;
    // data hash => signer => tx params
    mapping(bytes32 => mapping(address => SafeParams)) public safeParams;

    struct SafeParams {
        uint256 nonce;
        bytes signatures;
    }

    struct GasParams {
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
    }

    event AddedTx(
        bytes32 dataHash,
        address from,
        uint256 nonce,
        bytes signature
    );
    event SafeUpdated(address safe_);
    event ResetNonce(address signer_, bytes32 nonce_);

    error InvalidNonce();

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
        uint256 threshold = _validateNonce(nonce_, from_);
        bytes32 dataHash = keccak256(abi.encode(to_, value_, data_));

        bytes memory signs = signature_;
        if (threshold > 1) {
            uint256 totalSign = _storeSafeParams(
                from_,
                nonce_,
                dataHash,
                signature_
            );
            if (totalSign < threshold) return;
            signs = _getSignatures(dataHash, nonce_);
        }

        _relay(to_, value_, operation_, gasParams_, data_, signs);
    }

    function _validateNonce(
        uint256 nonce_,
        address from_
    ) internal returns (uint256 threshold) {
        if (safe.nonce() > nonce_ || lastNonce[from_] > nonce_)
            revert InvalidNonce();

        threshold = safe.getThreshold();
        lastNonce[from_] = nonce_;
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

    function _storeSafeParams(
        address from_,
        uint256 nonce_,
        bytes32 dataHash_,
        bytes memory signature_
    ) internal returns (uint256 totalSignatures) {
        owners[dataHash_][nonce_].push(from_);

        SafeParams storage _safeParams = safeParams[dataHash_][from_];
        _safeParams.signatures = signature_;
        _safeParams.nonce = nonce_;
        totalSignatures = owners[dataHash_][nonce_].length;
        emit AddedTx(dataHash_, from_, nonce_, signature_);
    }

    function _getSignatures(
        bytes32 dataHash_,
        uint256 nonce_
    ) internal view returns (bytes memory signature) {
        address[] memory txOwners = owners[dataHash_][nonce_];
        LibSort.insertionSort(txOwners);
        uint256 len = txOwners.length;

        for (uint256 index = 0; index < len; index++) {
            signature = abi.encodePacked(
                signature,
                safeParams[dataHash_][txOwners[index]].signatures
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

    function resetDataHash(bytes32 dataHash_) external {
        uint256 oldNonce = safeParams[dataHash_][msg.sender].nonce;
        delete safeParams[dataHash_][msg.sender];
        delete owners[dataHash_][oldNonce];

        uint256 nonce = safe.nonce();
        lastNonce[msg.sender] = nonce > 0 ? nonce - 1 : nonce;
        emit ResetNonce(msg.sender, dataHash_);
    }

    function getNonce() external view returns (uint256) {
        return safe.nonce();
    }

    function getSignature(
        bytes32 dataHash_,
        address from_
    ) public view returns (bytes memory) {
        return safeParams[dataHash_][from_].signatures;
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
