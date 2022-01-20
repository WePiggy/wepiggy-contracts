pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

//迁移合约：
//1.往reserveAddr地址中打入oldLpToken.balanceOf(breeder)数量的targetToken
//2.approve reserveAddr的targetToken给本合约
//3.在breeder中添加一个oldLpToken的矿池
//4.执行replaceMigrate

contract TokenMigrator {

    using SafeERC20 for IERC20;

    address public breeder;
    address public targetToken;
    address public reserveAddr;
    address public owner;

    constructor(address _breeder) public {
        breeder = _breeder;
        owner = msg.sender;
    }

    function setTargetToken(address _targetToken) public {
        require(msg.sender == owner, "only call by owner");
        targetToken = _targetToken;
    }

    function setReserveAddr(address _reserveAddr) public {
        require(msg.sender == owner, "only call by owner");
        reserveAddr = _reserveAddr;
    }

    function replaceMigrate(IERC20 oldLpToken) external returns (IERC20, uint){

        require(msg.sender == breeder, "not from breeder");

        address sender = msg.sender;
        uint256 value = oldLpToken.balanceOf(sender);

        oldLpToken.transferFrom(sender, reserveAddr, value);

        IERC20(targetToken).transferFrom(reserveAddr, sender, value);

        //返回占比
        return (IERC20(targetToken), value);
    }


}
