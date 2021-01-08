// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../token/PEther.sol";
import "../../token/PERC20.sol";
import "./ATokenInterface.sol";


contract ATokenMigrator {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public breeder;
    uint256 public notBeforeBlock;
    address payable public targetToken;

    constructor (address _breeder, uint256 _notBeforeBlock, address payable _targetToken) public {
        breeder = _breeder;
        notBeforeBlock = _notBeforeBlock;
        targetToken = _targetToken;
    }

    function replaceMigrate(ATokenInterface oldLpToken) external payable returns (PToken, uint){

        require(msg.sender == breeder, "not from breeder");
        require(block.number >= notBeforeBlock, "too early to migrate");

        address self = address(this);
        uint256 lp = oldLpToken.balanceOf(breeder);

        require(lp > 0, "balance must bigger than 0");

        address underlyingAssetAddress = oldLpToken.underlyingAssetAddress();
        uint256 oldBalance = 0;

        if (underlyingAssetAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            oldBalance = self.balance;
        } else {
            IERC20 token = IERC20(underlyingAssetAddress);
            oldBalance = token.balanceOf(self);
        }

        oldLpToken.transferFrom(breeder, self, lp);
        oldLpToken.redeem(lp);

        if (underlyingAssetAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {

            PEther newLpToken = PEther(targetToken);

            //获得赎回了多少代币
            uint redeemBal = self.balance.sub(oldBalance);

            // 将赎回的代币，抵押到wePiggy中，生成pToken
            newLpToken.mintForMigrate{value : redeemBal}(lp);

            // 获得抵押生成的pToken有多少
            uint mintBal = newLpToken.balanceOf(self);

            //将余额转到挖矿合约
            newLpToken.transferFrom(self, breeder, mintBal);

            //返回占比
            return (newLpToken, mintBal);

        } else {

            PERC20 newLpToken = PERC20(targetToken);
            require(underlyingAssetAddress == newLpToken.underlying(), "not match");

            //获得赎回了多少代币
            IERC20 token = IERC20(underlyingAssetAddress);
            uint redeemBal = token.balanceOf(self).sub(oldBalance);

            // 将赎回的代币，抵押到wePiggy中，生成pToken
            token.safeApprove(address(newLpToken), redeemBal);
            newLpToken.mintForMigrate(redeemBal, lp);

            // 获得抵押生成的pToken有多少
            uint mintBal = newLpToken.balanceOf(self);

            //将余额转到挖矿合约
            newLpToken.transferFrom(self, breeder, mintBal);

            return (newLpToken, mintBal);
        }

    }

    function migrate(ATokenInterface oldLpToken) external payable returns (PToken, uint){

        require(msg.sender == breeder, "not from breeder");
        require(block.number >= notBeforeBlock, "too early to migrate");

        address self = address(this);
        uint256 lp = oldLpToken.balanceOf(breeder);

        require(lp > 0, "balance must bigger than 0");

        // 从aToken中赎回相应的代币
        oldLpToken.transferFrom(breeder, self, lp);
        oldLpToken.redeem(lp);

        address underlyingAssetAddress = oldLpToken.underlyingAssetAddress();
        if (underlyingAssetAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {

            PEther newLpToken = PEther(targetToken);

            //获得赎回了多少代币
            uint redeemBal = self.balance;

            // 将赎回的代币，抵押到wePiggy中，生成pToken
            newLpToken.mint{value : redeemBal}();

            // 获得抵押生成的pToken有多少
            uint mintBal = newLpToken.balanceOf(self);

            //将余额转到挖矿合约
            newLpToken.transferFrom(self, breeder, mintBal);

            //返回占比
            return (newLpToken, mintBal);

        } else {

            PERC20 newLpToken = PERC20(targetToken);
            require(underlyingAssetAddress == newLpToken.underlying(), "not match");

            //获得赎回了多少代币
            uint redeemBal = 0;
            IERC20 token = IERC20(underlyingAssetAddress);
            redeemBal = token.balanceOf(self);

            // 将赎回的代币，抵押到wePiggy中，生成pToken
            token.safeApprove(address(newLpToken), redeemBal);
            newLpToken.mint(redeemBal);

            // 获得抵押生成的pToken有多少
            uint mintBal = newLpToken.balanceOf(self);

            //将余额转到挖矿合约
            newLpToken.transferFrom(self, breeder, mintBal);

            return (newLpToken, mintBal);
        }

    }

    receive() external payable {
    }

}
