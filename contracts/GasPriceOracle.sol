// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IGasPriceOracle.sol";
import "./interfaces/ITransmitManager.sol";
import "./utils/AccessControlExtended.sol";
import "./libraries/RescueFundsLib.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE} from "./utils/AccessRoles.sol";

/**
 * @title GasPriceOracle
 * @notice A contract to maintain and update gas prices across multiple chains.
 * It implements the IGasPriceOracle interface and uses AccessControlExtended to define roles and access permissions.
 * It also imports other contracts and libraries, including ITransmitManager for transmitting transactions across chains,
 * and RescueFundsLib for rescuing funds from contracts that have lost access to them.
 */
contract GasPriceOracle is IGasPriceOracle, AccessControlExtended {
    /**
     * @notice The ITransmitManager contract instance that is used to transmit transactions across chains.
     */
    ITransmitManager public transmitManager__;
    /**
     * @notice A mapping that stores the timestamp of the last update for each chain.
     */
    mapping(uint256 => uint256) public updatedAt;
    /**
     * @notice A mapping that stores the relative gas price of each chain.
     */
    mapping(uint32 => uint256) public override relativeGasPrice;
    /**
     * @notice A mapping that stores the next nonce of each transmitter.
     */
    mapping(address => uint256) public nextNonce;
    /**
     * @notice The gas price of the source chain.
     */
    uint256 public override sourceGasPrice;
    /**
     * @notice The chain slug of the contract.
     */
    uint32 public immutable chainSlug;

    /**
     * @notice An event that is emitted when the transmitManager is updated.
     * @param transmitManager The address of the new transmitManager.
     */
    event TransmitManagerUpdated(address transmitManager);
    /**
     * @notice An event that is emitted when the relative gas price of a chain is updated.
     * @param dstChainSlug The chain slug of the destination chain.
     * @param relativeGasPrice The new relative gas price of the destination chain.
     */
    event RelativeGasPriceUpdated(
        uint256 dstChainSlug,
        uint256 relativeGasPrice
    );
    /**
     * @notice An event that is emitted when the source gas price is updated.
     * @param sourceGasPrice The new source gas price.
     */
    event SourceGasPriceUpdated(uint256 sourceGasPrice);

    /**
     * @dev An error that is thrown when a transmitter is not found.
     */
    error TransmitterNotFound();
    /**
     * @dev An error that is thrown when an invalid nonce is provided.
     */
    error InvalidNonce();

    /**
     * @dev Constructs a new GasPriceOracle contract instance.
     * @param owner_ The address of the owner of the contract.
     * @param chainSlug_ The chain slug of the contract.
     */
    constructor(
        address owner_,
        uint32 chainSlug_
    ) AccessControlExtended(owner_) {
        chainSlug = chainSlug_;
    }

    /**
     * @notice update the sourceGasPrice which is to be used in various computations
     * @param sourceGasPrice_ gas price of source chain
     */
    function setSourceGasPrice(
        uint256 nonce_,
        uint256 sourceGasPrice_,
        bytes calldata signature_
    ) external {
        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                chainSlug,
                keccak256(abi.encode(chainSlug, nonce_, sourceGasPrice_)),
                signature_
            );

        if (!isTransmitter) revert TransmitterNotFound();

        uint256 nonce = nextNonce[transmitter]++;
        if (nonce_ != nonce) revert InvalidNonce();

        sourceGasPrice = sourceGasPrice_;
        updatedAt[chainSlug] = block.timestamp;

        emit SourceGasPriceUpdated(sourceGasPrice);
    }

    /**
     * @dev the relative prices are calculated as:
     * relativeGasPrice = (siblingGasPrice * siblingGasUSDPrice)/srcGasUSDPrice
     * It is assumed that precision of relative gas price will be same as src native tokens
     * So that when it is multiplied with gas limits at other contracts, we get correct values.
     */
    function setRelativeGasPrice(
        uint32 siblingChainSlug_,
        uint256 nonce_,
        uint256 relativeGasPrice_,
        bytes calldata signature_
    ) external {
        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                siblingChainSlug_,
                keccak256(
                    abi.encode(
                        chainSlug,
                        siblingChainSlug_,
                        nonce_,
                        relativeGasPrice_
                    )
                ),
                signature_
            );

        if (!isTransmitter) revert TransmitterNotFound();
        uint256 nonce = nextNonce[transmitter]++;
        if (nonce_ != nonce) revert InvalidNonce();

        relativeGasPrice[siblingChainSlug_] = relativeGasPrice_;
        updatedAt[siblingChainSlug_] = block.timestamp;

        emit RelativeGasPriceUpdated(siblingChainSlug_, relativeGasPrice_);
    }

    /**
     * @notice Returns the gas prices for a destination chain.
     * @param siblingChainSlug_ The identifier of the destination chain.
     */
    function getGasPrices(
        uint32 siblingChainSlug_
    ) external view override returns (uint256, uint256) {
        return (sourceGasPrice, relativeGasPrice[siblingChainSlug_]);
    }

    /**
     * @notice updates transmitManager_
     * @param transmitManager_ address of Transmit Manager
     */
    function setTransmitManager(
        ITransmitManager transmitManager_
    ) external onlyRole(GOVERNANCE_ROLE) {
        transmitManager__ = transmitManager_;
        emit TransmitManagerUpdated(address(transmitManager_));
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
