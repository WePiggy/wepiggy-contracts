// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

interface IPiggyBreeder {
    function stake(uint256 _pid, uint256 _amount) external;

    function unStake(uint256 _pid, uint256 _amount) external;

    function claim(uint256 _pid) external;

    function emergencyWithdraw(uint256 _pid) external;
}

contract WpcAirdropFundingManager is OwnableUpgradeSafe {

    IERC20 public piggy;
    IERC20 public token;
    IPiggyBreeder public piggyBreeder;

    event StakeTokenToPiggyBreeder(IERC20 token, uint pid, uint amount);
    event UnStakeTokenFromPiggyBreeder(IERC20 token, uint pid, uint amount);
    event ClaimWpcFromPiggyBreeder(uint pid);


    function initialize(IERC20 _token, IERC20 _piggy, IPiggyBreeder _piggyBreeder) public initializer {

        token = _token;
        piggy = _piggy;
        piggyBreeder = _piggyBreeder;

        super.__Ownable_init();
    }

    function _stakeTokenToPiggyBreeder(uint pid) public onlyOwner {
        uint amount = token.balanceOf(address(this));
        token.approve(address(piggyBreeder), amount);
        piggyBreeder.stake(pid, amount);
        emit StakeTokenToPiggyBreeder(token, pid, amount);
    }

    function _unStakeTokenFromPiggyBreeder(uint pid, uint amount) public onlyOwner {
        piggyBreeder.unStake(pid, amount);
        emit UnStakeTokenFromPiggyBreeder(token, pid, amount);
    }

    function _claimWpcFromPiggyBreeder(uint pid) public onlyOwner {
        piggyBreeder.claim(pid);
        emit ClaimWpcFromPiggyBreeder(pid);
    }

    // only owner can call this function.
    function _transferWpc(address _to, uint256 _amount) public onlyOwner {
        uint256 piggyBal = piggy.balanceOf(address(this));
        if (_amount > piggyBal) {
            piggy.transfer(_to, piggyBal);
        } else {
            piggy.transfer(_to, _amount);
        }
    }

}
