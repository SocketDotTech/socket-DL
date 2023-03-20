// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

import "./interfaces/IGasPriceOracle.sol";
import "./interfaces/ITransmitManager.sol";
import "./utils/AccessControl.sol";
import "./libraries/RescueFundsLib.sol";

contract GasPriceOracle is IGasPriceOracle, Ownable {
    ITransmitManager public transmitManager__;

    // plugs/switchboards/transmitter can use it to ensure prices are updated
    mapping(uint256 => uint256) public updatedAt;
    // chain slug => relative gas price
    mapping(uint256 => uint256) public override relativeGasPrice;

    mapping(address => mapping(uint256 => bool)) public nonces;

    // gas price of source chain
    uint256 public override sourceGasPrice;
    uint256 public immutable chainSlug;

    event GasPriceUpdated(uint256 dstChainSlug, uint256 relativeGasPrice);
    event TransmitManagerUpdated(address transmitManager);
    event SourceGasPriceUpdated(uint256 sourceGasPrice);

    error TransmitterNotFound();
    error SignatureAlreadyUsed();

    constructor(address owner_, uint256 chainSlug_) Ownable(owner_) {
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
        if (nonces[transmitter][nonce_]) revert SignatureAlreadyUsed();

        nonces[transmitter][nonce_] = true;
        sourceGasPrice = sourceGasPrice_;
        emit SourceGasPriceUpdated(sourceGasPrice);
    }

    /**
     * @dev the relative prices are calculated as:
     * relativeGasPrice = (siblingGasPrice * siblingGasUSDPrice)/srcGasUSDPrice
     * It is assumed that precision of relative gas price will be same as src native tokens
     * So that when it is multiplied with gas limits at other contracts, we get correct values.
     */
    function setRelativeGasPrice(
        uint256 siblingChainSlug_,
        uint256 nonce_,
        uint256 relativeGasPrice_,
        bytes calldata signature_
    ) external {
        (address transmitter, bool isTransmitter) = transmitManager__
            .checkTransmitter(
                siblingChainSlug_,
                keccak256(
                    abi.encode(siblingChainSlug_, nonce_, relativeGasPrice_)
                ),
                signature_
            );

        if (!isTransmitter) revert TransmitterNotFound();
        if (nonces[transmitter][nonce_]) revert SignatureAlreadyUsed();

        nonces[transmitter][nonce_] = true;
        relativeGasPrice[siblingChainSlug_] = relativeGasPrice_;
        updatedAt[siblingChainSlug_] = block.timestamp;

        emit GasPriceUpdated(siblingChainSlug_, relativeGasPrice_);
    }

    function getGasPrices(
        uint256 siblingChainSlug_
    ) external view override returns (uint256, uint256) {
        return (sourceGasPrice, relativeGasPrice[siblingChainSlug_]);
    }

    function setTransmitManager(
        ITransmitManager transmitManager_
    ) external onlyOwner {
        transmitManager__ = transmitManager_;
        emit TransmitManagerUpdated(address(transmitManager_));
    }

    function rescueFunds(
        address token_,
        address userAddress_,
        uint256 amount_
    ) external onlyOwner {
        RescueFundsLib.rescueFunds(token_, userAddress_, amount_);
    }
}
