// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControlExtended.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {ITransmitManager} from "../interfaces/ITransmitManager.sol";

import {FastSwitchboard} from "../switchboard/default-switchboards/FastSwitchboard.sol";
import {INativeRelay} from "../interfaces/INativeRelay.sol";

/**
 * @title SocketBatcher
 * @notice A contract that facilitates the batching of packets across chains. It manages requests for sealing, proposing, attesting, and executing packets across multiple chains.
 * It also has functions for setting gas limits, execution overhead, and registering switchboards.
 * @dev This contract uses the AccessControlExtended contract for managing role-based access control.
 */
contract SocketBatcher is AccessControlExtended {
    /*
     * @notice Constructs the SocketBatcher contract and grants the RESCUE_ROLE to the contract deployer.
     * @param owner_ The address of the contract deployer, who will be granted the RESCUE_ROLE.
     */
    constructor(address owner_) AccessControlExtended(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    /**
     * @notice A struct representing a request to seal a batch of packets on the source chain.
     * @param batchSize The number of packets to be sealed in the batch.
     * @param capacitorAddress The address of the capacitor contract on the source chain.
     * @param signature The signature of the packet data.
     */
    struct SealRequest {
        uint256 batchSize;
        address capacitorAddress;
        bytes signature;
    }

    /**
     * @notice A struct representing a proposal request for a packet.
     * @param packetId The ID of the packet being proposed.
     * @param root The Merkle root of the packet data.
     * @param signature The signature of the packet data.
     */
    struct ProposeRequest {
        bytes32 packetId;
        bytes32 root;
        bytes signature;
    }

    /**
     * @notice A struct representing an attestation request for a packet.
     * @param packetId The ID of the packet being attested.
     * @param srcChainSlug The slug of the source chain.
     * @param signature The signature of the packet data.
     */
    struct AttestRequest {
        bytes32 packetId;
        uint32 srcChainSlug;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to execute a packet.
     * @param packetId The ID of the packet to be executed.
     * @param localPlug The address of the local plug contract.
     * @param messageDetails The message details of the packet.
     * @param signature The signature of the packet data.
     */
    struct ExecuteRequest {
        bytes32 packetId;
        address localPlug;
        ISocket.MessageDetails messageDetails;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to initiate an Arbitrum native transaction.
     * @param packetId The ID of the packet to be executed.
     * @param maxSubmissionCost The maximum submission cost of the transaction.
     * @param maxGas The maximum amount of gas for the transaction.
     * @param gasPriceBid The gas price bid for the transaction.
     * @param callValue The call value of the transaction.
     */
    struct ArbitrumNativeInitiatorRequest {
        bytes32 packetId;
        uint256 maxSubmissionCost;
        uint256 maxGas;
        uint256 gasPriceBid;
        uint256 callValue;
    }

    /**
     * @notice A struct representing a request to set the propose gas limit for a chain.
     * @param nonce The nonce of the request.
     * @param dstChainId The ID of the destination chain.
     * @param proposeGasLimit The propose gas limit.
     * @param signature The signature of the request.
     */
    struct SetProposeGasLimitRequest {
        uint256 nonce;
        uint32 dstChainId;
        uint256 proposeGasLimit;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to set the attest gas limit for a chain.
     * @param nonce The nonce of the request.
     * @param dstChainId The ID of the destination chain.
     * @param attestGasLimit The propose gas limit.
     * @param signature The signature of the request.
     */
    struct SetAttestGasLimitRequest {
        uint256 nonce;
        uint32 dstChainId;
        uint256 attestGasLimit;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to set the execution overhead for a chain.
     * @param nonce The nonce of the request.
     * @param dstChainId The ID of the destination chain.
     * @param executionOverhead The propose gas limit.
     * @param signature The signature of the request.
     */
    struct SetExecutionOverheadRequest {
        uint256 nonce;
        uint32 dstChainId;
        uint256 executionOverhead;
        bytes signature;
    }

    /**
     * @notice A struct representing a request to register switchboard for a chain.
     * @param switchBoardAddress The switchboard address.
     * @param maxPacketLength The max packet length
     * @param siblingChainSlug The sibling chain slug
     * @param capacitorType The capacitor type
     */
    struct RegisterSwitchboardRequest {
        address switchBoardAddress;
        uint256 maxPacketLength;
        uint32 siblingChainSlug;
        uint32 capacitorType;
    }

    /**
     * @notice A struct representing a request to send proof to polygon root
     * @param proof proof to submit on root tunnel
     */
    struct ReceivePacketProofRequest {
        bytes proof;
    }

    /**
     * @notice set propose gas limit for a list of siblings
     * @param socketAddress_ address of socket
     * @param registerSwitchboardsRequests_ the list of requests with gas limit details
     */
    function registerSwitchboards(
        address socketAddress_,
        RegisterSwitchboardRequest[] calldata registerSwitchboardsRequests_
    ) external {
        uint256 registerSwitchboardsLength = registerSwitchboardsRequests_
            .length;
        for (uint256 index = 0; index < registerSwitchboardsLength; ) {
            ISocket(socketAddress_).registerSwitchBoard(
                registerSwitchboardsRequests_[index].switchBoardAddress,
                registerSwitchboardsRequests_[index].maxPacketLength,
                registerSwitchboardsRequests_[index].siblingChainSlug,
                registerSwitchboardsRequests_[index].capacitorType
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice set propose gas limit for a list of siblings
     * @param transmitManagerAddress_ address of transmit manager
     * @param setProposeGasLimitRequests_ the list of requests with gas limit details
     */
    function setProposeGasLimits(
        address transmitManagerAddress_,
        SetProposeGasLimitRequest[] calldata setProposeGasLimitRequests_
    ) external {
        uint256 setProposeGasLimitLength = setProposeGasLimitRequests_.length;
        for (uint256 index = 0; index < setProposeGasLimitLength; ) {
            ITransmitManager(transmitManagerAddress_).setProposeGasLimit(
                setProposeGasLimitRequests_[index].nonce,
                setProposeGasLimitRequests_[index].dstChainId,
                setProposeGasLimitRequests_[index].proposeGasLimit,
                setProposeGasLimitRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice set attest gas limit for a list of siblings
     * @param fastSwitchboardAddress_ address of fast switchboard
     * @param setAttestGasLimitRequests_ the list of requests with gas limit details
     */
    function setAttestGasLimits(
        address fastSwitchboardAddress_,
        SetAttestGasLimitRequest[] calldata setAttestGasLimitRequests_
    ) external {
        uint256 setAttestGasLimitLength = setAttestGasLimitRequests_.length;
        for (uint256 index = 0; index < setAttestGasLimitLength; ) {
            FastSwitchboard(fastSwitchboardAddress_).setAttestGasLimit(
                setAttestGasLimitRequests_[index].nonce,
                setAttestGasLimitRequests_[index].dstChainId,
                setAttestGasLimitRequests_[index].attestGasLimit,
                setAttestGasLimitRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice set execution overhead for a list of siblings
     * @param switchboardAddress_ address of fast switchboard
     * @param setExecutionOverheadRequests_ the list of requests with gas limit details
     */
    function setExecutionOverheadBatch(
        address switchboardAddress_,
        SetExecutionOverheadRequest[] calldata setExecutionOverheadRequests_
    ) external {
        uint256 sealRequestslength = setExecutionOverheadRequests_.length;
        for (uint256 index = 0; index < sealRequestslength; ) {
            FastSwitchboard(switchboardAddress_).setExecutionOverhead(
                setExecutionOverheadRequests_[index].nonce,
                setExecutionOverheadRequests_[index].dstChainId,
                setExecutionOverheadRequests_[index].executionOverhead,
                setExecutionOverheadRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice seal a batch of packets from capacitor on sourceChain mentioned in sealRequests
     * @param socketAddress_ address of socket
     * @param sealRequests_ the list of requests with packets to be sealed on sourceChain
     */
    function sealBatch(
        address socketAddress_,
        SealRequest[] calldata sealRequests_
    ) external {
        uint256 sealRequestslength = sealRequests_.length;
        for (uint256 index = 0; index < sealRequestslength; ) {
            ISocket(socketAddress_).seal(
                sealRequests_[index].batchSize,
                sealRequests_[index].capacitorAddress,
                sealRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice propose a batch of packets sequentially by socketDestination
     * @param socketAddress_ address of socket
     * @param proposeRequests_ the list of requests with packets to be proposed by socketDestination
     */
    function proposeBatch(
        address socketAddress_,
        ProposeRequest[] calldata proposeRequests_
    ) external {
        uint256 proposeRequestslength = proposeRequests_.length;
        for (uint256 index = 0; index < proposeRequestslength; ) {
            ISocket(socketAddress_).propose(
                proposeRequests_[index].packetId,
                proposeRequests_[index].root,
                proposeRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice attests a batch of Packets
     * @param switchBoardAddress_ address of switchboard
     * @param attestRequests_ the list of requests with packets to be attested by switchboard in sequence
     */
    function attestBatch(
        address switchBoardAddress_,
        AttestRequest[] calldata attestRequests_
    ) external {
        uint256 attestRequestslength = attestRequests_.length;
        for (uint256 index = 0; index < attestRequestslength; ) {
            FastSwitchboard(switchBoardAddress_).attest(
                attestRequests_[index].packetId,
                attestRequests_[index].srcChainSlug,
                attestRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice executes a batch of messages
     * @param socketAddress_ address of socket
     * @param executeRequests_ the list of requests with messages to be executed in sequence
     */
    function executeBatch(
        address socketAddress_,
        ExecuteRequest[] calldata executeRequests_
    ) external {
        uint256 executeRequestslength = executeRequests_.length;
        for (uint256 index = 0; index < executeRequestslength; ) {
            ISocket(socketAddress_).execute(
                executeRequests_[index].packetId,
                executeRequests_[index].localPlug,
                executeRequests_[index].messageDetails,
                executeRequests_[index].signature
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice invoke receieve Message on PolygonRootReceiver for a batch of messages in loop
     * @param polygonRootReceiverAddress_ address of polygonRootReceiver
     * @param receivePacketProofs_ the list of receivePacketProofs to be sent to receiveHook of polygonRootReceiver
     */
    function receiveMessageBatch(
        address polygonRootReceiverAddress_,
        ReceivePacketProofRequest[] calldata receivePacketProofs_
    ) external {
        uint256 receivePacketProofsLength = receivePacketProofs_.length;
        for (uint256 index = 0; index < receivePacketProofsLength; ) {
            INativeRelay(polygonRootReceiverAddress_).receiveMessage(
                receivePacketProofs_[index].proof
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice initiate NativeConfirmation on arbitrumChain for a batch of packets in loop
     * @param switchboardAddress_ address of nativeArbitrumSwitchboard
     * @param arbitrumNativeInitiatorRequests_ the list of requests with packets to initiate nativeConfirmation on switchboard of arbitrumChain
     */
    function initiateArbitrumNativeBatch(
        address switchboardAddress_,
        ArbitrumNativeInitiatorRequest[]
            calldata arbitrumNativeInitiatorRequests_
    ) external payable {
        uint256 arbitrumNativeInitiatorRequestsLength = arbitrumNativeInitiatorRequests_
                .length;
        for (
            uint256 index = 0;
            index < arbitrumNativeInitiatorRequestsLength;

        ) {
            INativeRelay(switchboardAddress_).initiateNativeConfirmation{
                value: arbitrumNativeInitiatorRequests_[index].callValue
            }(
                arbitrumNativeInitiatorRequests_[index].packetId,
                arbitrumNativeInitiatorRequests_[index].maxSubmissionCost,
                arbitrumNativeInitiatorRequests_[index].maxGas,
                arbitrumNativeInitiatorRequests_[index].gasPriceBid
            );
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice initiate NativeConfirmation on nativeChain(s) for a batch of packets in loop
     * @param switchboardAddress_ address of nativeSwitchboard
     * @param nativePacketIds_ the list of requests with packets to initiate nativeConfirmation on switchboard of native chains
     */
    function initiateNativeBatch(
        address switchboardAddress_,
        bytes32[] calldata nativePacketIds_
    ) external {
        uint256 nativePacketIdsLength = nativePacketIds_.length;
        for (uint256 index = 0; index < nativePacketIdsLength; ) {
            INativeRelay(switchboardAddress_).initiateNativeConfirmation(
                nativePacketIds_[index]
            );
            unchecked {
                ++index;
            }
        }
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
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
