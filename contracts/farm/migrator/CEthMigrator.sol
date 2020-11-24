// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./CTokenInterface.sol";
import "./ComptrollerInterface.sol";
import "../../token/PEther.sol";

contract CEthMigrator {

    address public breeder;
    uint256 public notBeforeBlock;
    address payable public targetToken;
    ComptrollerInterface comptroller;

    event Received(address, uint);

    constructor (address _breeder, uint256 _notBeforeBlock, address payable _targetToken, address _comptroller) public {
        breeder = _breeder;
        notBeforeBlock = _notBeforeBlock;
        targetToken = _targetToken;

        comptroller = ComptrollerInterface(_comptroller);
    }


    function replaceMigrate(CTokenInterface oldLpToken) external payable returns (PEther, uint){

        require(msg.sender == breeder, "not from breeder");
        require(block.number >= notBeforeBlock, "too early to migrate");

        address self = address(this);
        address sender = msg.sender;
        uint256 lp = oldLpToken.balanceOf(sender);

        PEther newLpToken = PEther(targetToken);
        if (lp == 0) {
            return (newLpToken, 0);
        }

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(oldLpToken);
        comptroller.enterMarkets(cTokens);

        // 从cToken中赎回相应的代币
        oldLpToken.transferFrom(sender, self, lp);
        oldLpToken.redeem(lp);

        //获得赎回了多少代币
        uint redeemBal = self.balance;

        // 将赎回的代币，抵押到wePiggy中，生成pToken
        newLpToken.mintForMigrate{value : redeemBal}(lp);

        // 获得抵押生成的pToken有多少
        uint mintBal = newLpToken.balanceOf(self);

        //将余额转到挖矿合约
        newLpToken.transferFrom(self, sender, mintBal);

        //返回占比
        return (newLpToken, mintBal);
    }

    function migrate(CTokenInterface oldLpToken) external payable returns (PEther, uint){

        require(msg.sender == breeder, "not from breeder");
        require(block.number >= notBeforeBlock, "too early to migrate");

        address self = address(this);
        address sender = msg.sender;
        uint256 lp = oldLpToken.balanceOf(sender);

        PEther newLpToken = PEther(targetToken);
        if (lp == 0) {
            return (newLpToken, 0);
        }

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(oldLpToken);
        comptroller.enterMarkets(cTokens);

        // 从cToken中赎回相应的代币
        oldLpToken.transferFrom(sender, self, lp);
        oldLpToken.redeem(lp);

        //获得赎回了多少代币
        uint redeemBal = self.balance;

        // 将赎回的代币，抵押到wePiggy中，生成pToken
        newLpToken.mint{value : redeemBal}();

        // 获得抵押生成的pToken有多少
        uint mintBal = newLpToken.balanceOf(self);

        //将余额转到挖矿合约
        newLpToken.transferFrom(self, sender, mintBal);

        //返回占比
        return (newLpToken, mintBal);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}



