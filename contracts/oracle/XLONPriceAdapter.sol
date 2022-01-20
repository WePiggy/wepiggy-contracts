pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC2O {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

contract XLONPriceAdapter is Ownable, AggregatorV3Interface {

    using SafeMath for uint256;
    address public immutable LON = 0x0000000000095413afC295d19EDeb1Ad7B71c952;
    address public immutable xLON = 0xf88506B0F1d30056B9e5580668D5875b9cd30F23;
    address public immutable LON_ORACLE = 0x13A8F2cC27ccC2761ca1b21d2F3E762445f201CE;

    function decimals() override external view returns (uint8){
        return 18;
    }

    function description() override external view returns (string memory){
        return "xLON / ETH";
    }

    function version() override external view returns (uint256){
        return 1;
    }

    function getRoundData(uint80 _roundId)
    override
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(LON_ORACLE);
        (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt, uint80 answeredInRound) = priceFeed.getRoundData(_roundId);
        uint256 _exchangeRate = exchangeRate();
        int256 price = int256(uint(answer).mul(_exchangeRate).div(1 ether));
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }

    function latestRoundData()
    override
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(LON_ORACLE);
        (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        uint256 _exchangeRate = exchangeRate();
        int256 price = int256(uint(answer).mul(_exchangeRate).div(1 ether));
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }

    function exchangeRate() public view returns (uint256) {
        uint256 exchangeRate = (IERC2O(LON).balanceOf(xLON).mul(1 ether)).div(IERC2O(xLON).totalSupply());
        return exchangeRate;
    }

}
