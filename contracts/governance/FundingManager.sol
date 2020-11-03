// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../token/WePiggyToken.sol";

contract FundingManager is Ownable {

    using SafeMath for uint256;

    struct FundingHolderInfo {
        uint256 ratio;
        string name;
        address addr;
    }

    // The WePiggyToken !
    WePiggyToken public piggy;

    // Info of each funding.
    FundingHolderInfo[] public fundingHolders;

    constructor(WePiggyToken _piggy) public {
        piggy = _piggy;
    }


    // Safe piggy transfer function, just in case if rounding error causes pool to not have enough PiggyToken.
    function safePiggyTransfer(address _to, uint256 _amount) internal {
        uint256 piggyBal = piggy.balanceOf(address(this));
        if (_amount > piggyBal) {
            piggy.transfer(_to, piggyBal);
        } else {
            piggy.transfer(_to, _amount);
        }
    }

    //Update funding pool
    function addFunding(string memory _name, address _addr, uint256 _ratio) public onlyOwner {

        fundingHolders.push(FundingHolderInfo({
        name : _name,
        addr : _addr,
        ratio : _ratio
        }));

    }

    //Update funding pool
    function setFunding(uint256 pid, string memory _name, address _addr, uint256 _ratio) public onlyOwner {

        FundingHolderInfo storage fhi = fundingHolders[pid];

        fhi.name = _name;
        fhi.addr = _addr;
        fhi.ratio = _ratio;
    }

    // Return the pool pending balance.
    function getPendingBalance(uint256 pid) public view returns (uint256){
        FundingHolderInfo storage fhi = fundingHolders[pid];
        uint256 piggyBal = piggy.balanceOf(address(this));
        uint _amount = piggyBal.mul(fhi.ratio).div(100);
        return _amount;
    }

    //claim wpc. every can call this function, but transfer token to
    function claim() public {
        uint256 piggyBal = piggy.balanceOf(address(this));
        for (uint256 i = 0; i < fundingHolders.length; i++) {
            FundingHolderInfo storage fhi = fundingHolders[i];
            uint _amount = piggyBal.mul(fhi.ratio).div(100);
            safePiggyTransfer(fhi.addr, _amount);
        }

    }

}