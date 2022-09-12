// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/Ownable.sol";

contract SocketGasToken is ERC20, Ownable {
    string name_ = "Socket Gas Token";
    string symbol_ = "SGT";

    constructor(uint256 chainId_)
        Ownable(msg.sender)
        ERC20(
            string(abi.encode(name_, "-", chainId_)),
            string(abi.encode(symbol_, "-", chainId_))
        )
    {}

    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    function burnFrom(address from_, uint256 amount_) external onlyOwner {
        _burn(from_, amount_);
    }
}
