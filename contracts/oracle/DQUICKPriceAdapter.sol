pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC2O {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

interface DragonLair {
    function dQUICKForQUICK(uint256 _dQuickAmount) external view returns (uint256);

    function QUICKForDQUICK(uint256 _quickAmount) external view returns (uint256);
}

contract DQUICKPriceAdapter is Ownable, AggregatorV3Interface {


    using SafeMath for uint256;
    address public QUICK;
    address public dQUICK;
    address public QUICK_ORACLE;


    constructor(address _QUICK, address _dQUICK, address _QUICK_ORACLE) public {
        QUICK = _QUICK;
        dQUICK = _dQUICK;
        QUICK_ORACLE = _QUICK_ORACLE;
    }

    function decimals() override external view returns (uint8){
        return 8;
    }

    function description() override external view returns (string memory){
        return "dQUICK / USD";
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
        AggregatorV3Interface priceFeed = AggregatorV3Interface(QUICK_ORACLE);
        (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt, uint80 answeredInRound) = priceFeed.getRoundData(_roundId);
        uint256 _exchangeRate = exchangeRate();
        int256 price = int256(uint(answer).mul(_exchangeRate).div(1e18));
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
        AggregatorV3Interface priceFeed = AggregatorV3Interface(QUICK_ORACLE);
        (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        uint256 _exchangeRate = exchangeRate();
        int256 price = int256(uint(answer).mul(_exchangeRate).div(1e18));
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }

    function exchangeRate() public view returns (uint256) {
        uint amount = uint256(1).mul(1e18);
        uint quickAmount = DragonLair(dQUICK).dQUICKForQUICK(amount);
        return quickAmount;
    }


}
