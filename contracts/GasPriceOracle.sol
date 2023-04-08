// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IGasPriceOracle.sol";
import "./interfaces/ITransmitManager.sol";
import "./utils/AccessControlExtended.sol";
import "./libraries/RescueFundsLib.sol";
import {GOVERNANCE_ROLE, RESCUE_ROLE} from "./utils/AccessRoles.sol";

contract GasPriceOracle is IGasPriceOracle, AccessControlExtended {
    ITransmitManager public transmitManager__;

    // plugs/switchboards/transmitter can use it to ensure prices are updated
    mapping(uint256 => uint256) public updatedAt;
    // chain slug => relative gas price
    mapping(uint32 => uint256) public override relativeGasPrice;

    // transmitter => nextNonce
    mapping(address => uint256) public nextNonce;

    // gas price of source chain
    uint256 public override sourceGasPrice;
    uint32 public immutable chainSlug;

    event TransmitManagerUpdated(address transmitManager);
    event RelativeGasPriceUpdated(
        uint256 dstChainSlug,
        uint256 relativeGasPrice
    );
    event SourceGasPriceUpdated(uint256 sourceGasPrice);

    error TransmitterNotFound();
    error InvalidNonce();

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

    function getGasPrices(
        uint32 siblingChainSlug_
    ) external view override returns (uint256, uint256) {
        return (sourceGasPrice, relativeGasPrice[siblingChainSlug_]);
    }

    function setTransmitManager(
        ITransmitManager transmitManager_
    ) external onlyRole(GOVERNANCE_ROLE) {
        transmitManager__ = transmitManager_;
        emit TransmitManagerUpdated(address(transmitManager_));
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
