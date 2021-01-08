pragma solidity 0.6.12;

import "./ATokenInterface.sol";
import "../../token/PEther.sol";
import "../../token/PERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AToken2PTokenMigrator is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => bool) public aTokenMapping;
    mapping(address => bool) public pTokenMapping;

    constructor() public {

    }

    function migrate(address aToken, address payable pToken, uint amount) public {

        require(aTokenMapping[aToken], "bad aToken");
        require(pTokenMapping[pToken], "bad pToken");

        ATokenInterface aTokenInstance = ATokenInterface(aToken);

        uint aTokenBalance = aTokenInstance.balanceOf(msg.sender);
        require(amount <= aTokenBalance, "error amount");

        address underlyingAssetAddress = aTokenInstance.underlyingAssetAddress();

        //验证需要转换的两个代币是否正确
        if (underlyingAssetAddress == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            PEther pEth = PEther(pToken);
            require(compareStrings(pEth.symbol(), "pETH"), "aToken and pToken not match");
        } else {
            PERC20 pErc20 = PERC20(pToken);
            require(pErc20.underlying() == underlyingAssetAddress, "aToken and pToken not match");
        }

        //将代币转到本合约
        address self = address(this);
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
            newLpToken.approve(self, mintedBalance);
            newLpToken.transferFrom(self, msg.sender, mintedBalance);
        } else {

            PERC20 newLpToken = PERC20(pToken);
            uint pTokenBeforeBalance = _getTokenBalance(pToken);

            IERC20(underlyingAssetAddress).safeApprove(address(newLpToken), redeemedBalance);
            newLpToken.mint(redeemedBalance);

            uint pTokenAfterBalance = _getTokenBalance(pToken);
            mintedBalance = pTokenAfterBalance.sub(pTokenBeforeBalance);

            //将pToken转给用户
            newLpToken.approve(self, mintedBalance);
            newLpToken.transferFrom(self, msg.sender, mintedBalance);
        }

    }


    function set(address[] memory aTokens, address[] memory pTokens) public onlyOwner {

        for (uint i = 0; i < aTokens.length; i++) {
            address aToken = aTokens[i];
            aTokenMapping[aToken] = true;
        }

        for (uint i = 0; i < pTokens.length; i++) {
            address pToken = pTokens[i];
            pTokenMapping[pToken] = true;
        }

    }

    function setATokenMapping(address aToken, bool isAvailable) public onlyOwner {
        aTokenMapping[aToken] = isAvailable;
    }

    function setPTokenMapping(address pToken, bool isAvailable) public onlyOwner {
        pTokenMapping[pToken] = isAvailable;
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
