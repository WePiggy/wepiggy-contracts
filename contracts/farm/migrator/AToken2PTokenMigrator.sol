pragma solidity 0.6.12;

import "./ATokenInterface.sol";
import "../../token/PEther.sol";
import "../../token/PERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract AToken2PTokenMigrator {

    using SafeMath for uint256;

    constructor() public {

    }


    function migrate(address aToken, address payable pToken, uint amount) public {

        address self = address(this);

        ATokenInterface aTokenInstance = ATokenInterface(aToken);
        address underlyingAssetAddress = aTokenInstance.underlyingAssetAddress();

        //验证需要转换的两个代币是否正确
        if (underlyingAssetAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            PEther pEth = PEther(pToken);
            require(compareStrings(pEth.symbol(), "pETH"), "aToken and pToken not match");
        } else {
            PERC20 pErc20 = PERC20(pToken);
            require(pErc20.underlying() == underlyingAssetAddress, "aToken and pToken not match");
        }

        uint aTokenBalance = aTokenInstance.balanceOf(msg.sender);
        require(amount <= aTokenBalance, "error amount");

        //将代币转到本合约
        aTokenInstance.transferFrom(msg.sender, self, amount);

        //从AToken中赎回基础币
        uint beforeBalance = _getTokenBalance(underlyingAssetAddress);
        aTokenInstance.redeem(amount);
        uint afterBalance = _getTokenBalance(underlyingAssetAddress);
        uint redeemedBalance = afterBalance.sub(beforeBalance);

        //将基础币抵押给pToken
        uint mintedBalance = 0;
        if (underlyingAssetAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {

            PEther newLpToken = PEther(pToken);
            uint pTokenBeforeBalance = _getTokenBalance(pToken);
            newLpToken.mint{value : redeemedBalance}();
            uint pTokenAfterBalance = _getTokenBalance(pToken);
            mintedBalance = pTokenAfterBalance.sub(pTokenBeforeBalance);

            //将pToken转给用户
            newLpToken.transferFrom(self, msg.sender, mintedBalance);
        } else {

            PERC20 newLpToken = PERC20(pToken);
            uint pTokenBeforeBalance = _getTokenBalance(pToken);

            IERC20(underlyingAssetAddress).approve(address(newLpToken), redeemedBalance);
            newLpToken.mint(redeemedBalance);

            uint pTokenAfterBalance = _getTokenBalance(pToken);
            mintedBalance = pTokenAfterBalance.sub(pTokenBeforeBalance);

            //将pToken转给用户
            newLpToken.approve(self, mintedBalance);
            newLpToken.transferFrom(self, msg.sender, mintedBalance);
        }
        
    }

    function _getTokenBalance(address tokenAddress) internal returns (uint){
        if (tokenAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            return address(this).balance;
        } else {
            IERC20 token = IERC20(tokenAddress);
            return token.balanceOf(address(this));
        }
    }


    receive() external payable {
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }


}
