// SPDX-License-Identifier: MIT
// See: ../../comptroller/IComptroller.sol
pragma solidity ^0.6.0;

interface ComptrollerInterface {
    function enterMarkets(address[] calldata pTokens) external returns (uint[] memory);

    function exitMarket(address pTokenAddress) external returns (uint);

    function mintAllowed(address pToken, address minter, uint mintAmount) external returns (uint);

    function mintVerify(address pToken, address minter, uint mintAmount, uint mintTokens) external;

    function redeemAllowed(address pToken, address redeemer, uint redeemTokens) external returns (uint);

    function redeemVerify(address pToken, address redeemer, uint redeemAmount, uint redeemTokens) external;

    function borrowAllowed(address pToken, address borrower, uint borrowAmount) external returns (uint);

    function borrowVerify(address pToken, address borrower, uint borrowAmount) external;

    function repayBorrowAllowed(address pToken, address payer, address borrower, uint repayAmount) external returns (uint);

    function repayBorrowVerify(address pToken, address payer, address borrower, uint repayAmount, uint borrowerIndex) external;

    function liquidateBorrowAllowed(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount) external returns (uint);

    function liquidateBorrowVerify(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount, uint seizeTokens) external;

    function seizeAllowed(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external returns (uint);

    function seizeVerify(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external;

    function transferAllowed(address pToken, address src, address dst, uint transferTokens) external returns (uint);

    function transferVerify(address pToken, address src, address dst, uint transferTokens) external;

    function liquidateCalculateSeizeTokens(address pTokenBorrowed, address pTokenCollateral, uint repayAmount) external view returns (uint, uint);
}
