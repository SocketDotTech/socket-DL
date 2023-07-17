// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "./SwitchboardBase.sol";

/**
 * @title OptimisticSwitchboard
 * @notice A contract that extends the SwitchboardBase contract and implements the
 * allowPacket and fee getter functions.
 */
contract OptimisticSwitchboard is SwitchboardBase {
    /**
     * @notice Creates an OptimisticSwitchboard instance with the specified parameters.
     * @param owner_ The address of the contract owner.
     * @param socket_ The address of the socket contract.
     * @param chainSlug_ The chain slug.
     * @param timeoutInSeconds_ The timeout period in seconds after which proposals become valid if not tripped.
     * @param signatureVerifier_ The address of the signature verifier contract
     */
    constructor(
        address owner_,
        address socket_,
        uint32 chainSlug_,
        uint256 timeoutInSeconds_,
        ISignatureVerifier signatureVerifier_
    )
        AccessControlExtended(owner_)
        SwitchboardBase(
            socket_,
            chainSlug_,
            timeoutInSeconds_,
            signatureVerifier_
        )
    {}

    /**
     * @inheritdoc ISwitchboard
     */
    function allowPacket(
        bytes32,
        bytes32 packetId_,
        uint256 proposalCount_,
        uint32 srcChainSlug_,
        uint256 proposeTime_
    ) external view override returns (bool) {
        uint64 packetCount = uint64(uint256(packetId_));

        // any relevant trips triggered or invalid packet count.
        if (
            isGlobalTipped ||
            isPathTripped[srcChainSlug_] ||
            isProposalTripped[packetId_][proposalCount_] ||
            packetCount < initialPacketCount[srcChainSlug_]
        ) return false;

        // time to detect and call trip is not over.
        if (block.timestamp - proposeTime_ < timeoutInSeconds) return false;

        // enough time has passed without trip
        return true;
    }

    /**
     * @inheritdoc ISwitchboard
     */
    function setFees(
        uint256 nonce_,
        uint32 dstChainSlug_,
        uint128 switchboardFees_,
        uint128 verificationOverheadFees_,
        bytes calldata signature_
    ) external override {
        address feesUpdater = signatureVerifier__.recoverSigner(
            keccak256(
                abi.encode(
                    FEES_UPDATE_SIG_IDENTIFIER,
                    address(this),
                    chainSlug,
                    dstChainSlug_,
                    nonce_,
                    switchboardFees_,
                    verificationOverheadFees_
                )
            ),
            signature_
        );

        _checkRoleWithSlug(FEES_UPDATER_ROLE, dstChainSlug_, feesUpdater);
        // Nonce is used by gated roles and we don't expect nonce to reach the max value of uint256
        unchecked {
            if (nonce_ != nextNonce[feesUpdater]++) revert InvalidNonce();
        }

        Fees storage fee = fees[dstChainSlug_];
        fee.verificationOverheadFees = verificationOverheadFees_;
        fee.switchboardFees = switchboardFees_;

        emit SwitchboardFeesSet(dstChainSlug_, fee);
    }
}
