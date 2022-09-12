// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/Ownable.sol";

contract SocketGasToken is ERC20, Ownable {
    string private constant name_ = "Socket Gas Token";
    string private constant symbol_ = "SGT";

    /**
     * @notice initialises the contract with chain id
     * @dev vault deploys the token and becomes owner for executing mint and burn
     */
    constructor(uint256 chainId_)
        Ownable(msg.sender)
        ERC20(
            string(abi.encode(name_, "-", chainId_)),
            string(abi.encode(symbol_, "-", chainId_))
        )
    {}

    /**
     * @notice mint the `amount_` tokens to `to_` address
     */
    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    /**
     * @notice burns the `amount_` tokens from `from_` address
     */
    function burnFrom(address from_, uint256 amount_) external onlyOwner {
        _burn(from_, amount_);
    }
}
