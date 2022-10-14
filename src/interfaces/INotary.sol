// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

interface INotary {
    struct PacketDetails {
        bool isPaused;
        bytes32 remoteRoots;
        uint256 attestations;
        uint256 timeRecord;
    }

    enum PacketStatus {
        NOT_PROPOSED,
        PROPOSED,
        PAUSED
    }

    /**
     * @notice emits when a new signature verifier contract is set
     * @param signatureVerifier_ address of new verifier contract
     */
    event SignatureVerifierSet(address signatureVerifier_);

    /**
     * @notice emits the verification and seal confirmation of a packet
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
     * @notice emits when a packet is challenged at src
     * @param attester address of packet attester
     * @param accumAddress address of accumulator at src
     * @param packetId packed id
     * @param challenger challenger address
     * @param rewardAmount amount slashed from attester is provided to challenger
     */
    event ChallengedSuccessfully(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId,
        address challenger,
        uint256 rewardAmount
    );

    /**
     * @notice emits the packet details when proposed at remote
     * @param remoteChainSlug src chain id
     * @param accumAddress address of accumulator at src
     * @param packetId packed id
     */
    event Proposed(
        uint256 indexed remoteChainSlug,
        address indexed accumAddress,
        uint256 indexed packetId,
        bytes32 root
    );

    /**
     * @notice emits when a packet is unpaused by owner
     * @param accumAddress address of accumulator at src
     * @param packetId packed id
     */
    event PacketUnpaused(
        address indexed accumAddress,
        uint256 indexed packetId
    );

    /**
     * @notice emits when a packet is paused
     * @param accumAddress address of accumulator at src
     * @param packetId packed id
     * @param challenger challenger address
     */
    event PausedPacket(
        address indexed accumAddress,
        uint256 indexed packetId,
        address challenger
    );

    /**
     * @notice emits when a root is confirmed by attester at remote
     * @param attester address of packet attester
     * @param accumAddress address of accumulator at src
     * @param packetId packed id
     */
    event RootConfirmed(
        address indexed attester,
        address indexed accumAddress,
        uint256 indexed packetId,
        uint256 remoteChainSlug_
    );

    error InvalidAttester();

    error AlreadyProposed();

    error AttesterExists();

    error AttesterNotFound();

    error AccumAlreadyAdded();

    error AlreadyAttested();

    error NotFastPath();

    error PacketPaused();

    error PacketNotPaused();

    error ZeroAddress();

    error RootNotFound();

    /**
     * @notice verifies the attester and seals a packet
     * @param accumAddress_ address of accumulator at local
     * @param signature_ signature of attester
     */
    function seal(address accumAddress_, bytes calldata signature_) external;

    /**
     * @notice challenges a packet at local if wrongly attested
     * @param accumAddress_ address of accumulator at local
     * @param root_ root hash of packet
     * @param packetId_ packed id
     * @param signature_ address of original attester
     */
    function challengeSignature(
        bytes32 root_,
        uint256 packetId_,
        uint256 remoteChainSlug_,
        address accumAddress_,
        bytes calldata signature_
    ) external;

    /**
     * @notice to propose a new packet
     * @param remoteChainSlug_ src chain id
     * @param accumAddress_ address of accumulator at src
     * @param packetId_ packed id
     * @param root_ root hash of packet
     * @param signature_ signature of proposer
     */
    function propose(
        uint256 remoteChainSlug_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external;

    /**
     * @notice to confirm a packet on remote
     * @dev depending on paths, it may be a requirement to have on-chain confirmations for a packet
     * @param remoteChainSlug_ src chain id
     * @param accumAddress_ address of accumulator at src
     * @param packetId_ packed id
     * @param root_ root hash of packet
     * @param signature_ signature of proposer
     */
    function confirmRoot(
        uint256 remoteChainSlug_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external;

    /**
     * @notice returns the root of given packet
     * @param remoteChainSlug_ remote chain id
     * @param accumAddress_ address of accumulator at src
     * @param packetId_ packed id
     * @return root_ root hash
     */
    function getRemoteRoot(
        uint256 remoteChainSlug_,
        address accumAddress_,
        uint256 packetId_
    ) external view returns (bytes32 root_);

    /**
     * @notice returns the packet status
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainSlug_ src chain id
     * @param packetId_ packed id
     * @return status_ status as enum PacketStatus
     */
    function getPacketStatus(
        address accumAddress_,
        uint256 remoteChainSlug_,
        uint256 packetId_
    ) external view returns (PacketStatus status_);

    /**
     * @notice returns the packet details needed by verifier
     * @param accumAddress_ address of accumulator at src
     * @param remoteChainSlug_ src chain id
     * @param packetId_ packed id
     * @return status packet status
     * @return packetArrivedAt time at which packet was proposed
     * @return pendingAttestations number of attestations remaining
     * @return root root hash
     */
    function getPacketDetails(
        address accumAddress_,
        uint256 remoteChainSlug_,
        uint256 packetId_
    )
        external
        view
        returns (
            PacketStatus status,
            uint256 packetArrivedAt,
            uint256 pendingAttestations,
            bytes32 root
        );
}
