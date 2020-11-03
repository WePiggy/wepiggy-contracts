// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../token/WePiggyToken.sol";

// funding holder. Will call by gnosis-safe
contract FundingHolder is Ownable {

    // The WePiggyToken !
    WePiggyToken public piggy;

    constructor(WePiggyToken _piggy) public {
        piggy = _piggy;
    }

    // only owner can call this function.
    function transfer(address _to, uint256 _amount) public onlyOwner {
        uint256 piggyBal = piggy.balanceOf(address(this));
        if (_amount > piggyBal) {
            piggy.transfer(_to, piggyBal);
        } else {
            piggy.transfer(_to, _amount);
        }
    }

}
