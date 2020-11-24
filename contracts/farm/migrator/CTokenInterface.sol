// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface CTokenInterface {

    function transfer(address dst, uint amount) external returns (bool);

    function transferFrom(address src, address dst, uint amount) external returns (bool);

    function approve(address spender, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function balanceOfUnderlying(address owner) external returns (uint);

    function redeem(uint redeemTokens) external returns (uint);

    function underlying() external view returns (address);

}


