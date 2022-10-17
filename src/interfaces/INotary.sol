// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface INotary {
    struct PacketDetails {
        bytes32 remoteRoots;
        uint256 attestations;
        uint256 timeRecord;
    }

    enum PacketStatus {
        NOT_PROPOSED,
        PROPOSED
    }

    /**
     * @notice emits when a new signature verifier contract is set
     * @param signatureVerifier_ address of new verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier_);

    /**
     * @notice emits the verification and seal confirmation of a packet
     * @param attester address of attester
     * @param accumAddress address of accumulator at local
     * @param packetId packed id
     * @param signature signature of attester
     */
    event PacketVerifiedAndSealed(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId,
        bytes signature
    );

    /**
     * @notice emits the packet details when proposed at remote
     * @param packetId packet id
     * @param root packet root
     */
    event PacketProposed(uint256 indexed packetId, bytes32 root);

    /**
     * @notice emits when a packet is attested by attester at remote
     * @param attester address of attester
     * @param packetId packet id
     */
    event PacketAttested(address indexed attester, uint256 indexed packetId);

    error InvalidAttester();
    error AttesterExists();
    error AttesterNotFound();
    error AlreadyAttested();

    /**
     * @notice verifies the attester and seals a packet
     * @param accumAddress_ address of accumulator at local
     * @param signature_ signature of attester
     */
    function seal(address accumAddress_, bytes calldata signature_) external;

    /**
     * @notice to propose a new packet
     * @param packetId_ packet id
     * @param root_ root hash of packet
     * @param signature_ signature of proposer
     */
    function attest(
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external;

    /**
     * @notice returns the root of given packet
     * @param packetId_ packet id
     * @return root_ root hash
     */
    function getRemoteRoot(uint256 packetId_)
        external
        view
        returns (bytes32 root_);

    /**
     * @notice returns the packet status
     * @param packetId_ packet id
     * @return status_ status as enum PacketStatus
     */
    function getPacketStatus(uint256 packetId_)
        external
        view
        returns (PacketStatus status_);

    /**
     * @notice returns the packet details needed by verifier
     * @param packetId_ packet id
     * @return status packet status
     * @return packetArrivedAt time at which packet was proposed
     * @return pendingAttestations number of attestations remaining
     * @return root root hash
     */
    function getPacketDetails(uint256 packetId_)
        external
        view
        returns (
            PacketStatus status,
            uint256 packetArrivedAt,
            uint256 pendingAttestations,
            bytes32 root
        );
}
