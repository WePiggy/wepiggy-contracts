// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockERC20 is ERC20 {

    constructor(string memory name, string memory symbol, uint256 initialSupply, uint8 decimals) public ERC20(name, symbol){
        _setupDecimals(decimals);
        _mint(msg.sender, initialSupply);
    }
}