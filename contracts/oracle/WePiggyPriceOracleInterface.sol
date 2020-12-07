// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../token/PToken.sol";

interface WePiggyPriceOracleInterface {


    function getPrice(address token) external view returns (uint);

    function setPrice(address token, uint price, bool force) external;

}