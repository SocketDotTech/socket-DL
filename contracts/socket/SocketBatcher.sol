// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "../libraries/RescueFundsLib.sol";
import "../utils/AccessControlExtended.sol";
import {RESCUE_ROLE} from "../utils/AccessRoles.sol";
import {ISocket} from "../interfaces/ISocket.sol";
import {ITransmitManager} from "../interfaces/ITransmitManager.sol";

import {FastSwitchboard} from "../switchboard/default-switchboards/FastSwitchboard.sol";
import {INativeRelay} from "../interfaces/INativeRelay.sol";

contract SocketBatcher is AccessControlExtended {
    constructor(address owner_) AccessControlExtended(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    struct SealRequest {
        uint256 batchSize;
        address capacitorAddress;
        bytes signature;
    }

    struct ProposeRequest {
        bytes32 packetId;
        bytes32 root;
        bytes signature;
    }

    struct AttestRequest {
        bytes32 packetId;
        uint256 srcChainSlug;
        bytes signature;
    }

    struct ExecuteRequest {
        bytes32 packetId;
        address localPlug;
        ISocket.MessageDetails messageDetails;
        bytes signature;
    }

    struct ArbitrumNativeInitiatorRequest {
        bytes32 packetId;
        uint256 maxSubmissionCost;
        uint256 maxGas;
        uint256 gasPriceBid;
        uint256 callValue;
    }

    struct SetProposeGasLimitRequest {
        uint256 nonce;
        uint256 dstChainId;
        uint256 proposeGasLimit;
        bytes signature;
    }

    struct SetAttestGasLimitRequest {
        uint256 nonce;
        uint256 dstChainId;
        uint256 attestGasLimit;
        bytes signature;
    }

    struct SetExecutionOverheadRequest {
        uint256 nonce;
        uint256 dstChainId;
        uint256 executionOverhead;
        bytes signature;
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
        bytes[] calldata receivePacketProofs_
    ) external {
        uint256 receivePacketProofsLength = receivePacketProofs_.length;
        for (uint256 index = 0; index < receivePacketProofsLength; ) {
            INativeRelay(polygonRootReceiverAddress_).receiveMessage(
                receivePacketProofs_[index]
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

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
