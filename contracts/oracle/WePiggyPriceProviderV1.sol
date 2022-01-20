pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./WePiggyPriceOracleInterface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface PTokenInterface {
    function underlying() external view returns (address);

    function symbol() external view returns (string memory);
}

interface CompoundPriceOracleInterface {
    enum PriceSource {
        FIXED_ETH, /// implies the fixedPrice is a constant multiple of the ETH price (which varies)
        FIXED_USD, /// implies the fixedPrice is a constant multiple of the USD price (which is 1)
        REPORTER   /// implies the price is set by the reporter
    }

    /// @dev Describe how the USD price should be determined for an asset.
    ///  There should be 1 TokenConfig object for each supported asset, passed in the constructor.
    struct CTokenConfig {
        address cToken;
        address underlying;
        bytes32 symbolHash;
        uint256 baseUnit;
        PriceSource priceSource;
        uint256 fixedPrice;
        address uniswapMarket;
        bool isUniswapReversed;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint);

    function getTokenConfigByUnderlying(address underlying) external view returns (CTokenConfig memory);

    function getTokenConfigBySymbol(string memory symbol) external view returns (CTokenConfig memory);
}

contract WePiggyPriceProviderV1 is Ownable {

    using SafeMath for uint256;

    enum PriceOracleType{
        ChainLink,
        Compound,
        Customer,
        ChainLinkEthBase
    }

    struct PriceOracle {
        address source;
        PriceOracleType sourceType;
        bool available;
    }

    //Config for pToken
    struct TokenConfig {
        address pToken;
        address underlying;
        string underlyingSymbol; //example: DAI
        uint256 baseUnit; //example: 1e18
        bool fixedUsd; //if true,will return 1*e36/baseUnit
    }


    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => PriceOracle[]) public oracles;
    mapping(address => address) public chainLinkTokenEthPriceFeed;

    address public ethUsdPriceFeedAddress;

    event ConfigUpdated(address pToken, address underlying, string underlyingSymbol, uint256 baseUnit, bool fixedUsd);
    event PriceOracleUpdated(address pToken, PriceOracle[] oracles);


    constructor() public {
    }


    function getUnderlyingPrice(address _pToken) external view returns (uint){

        uint256 price = 0;
        TokenConfig storage tokenConfig = tokenConfigs[_pToken];
        if (tokenConfig.fixedUsd) {//if true,will return 1*e36/baseUnit
            price = 1;
            return price.mul(1e36).div(tokenConfig.baseUnit);
        }

        PriceOracle[] storage priceOracles = oracles[_pToken];
        for (uint256 i = 0; i < priceOracles.length; i++) {
            PriceOracle storage priceOracle = priceOracles[i];
            if (priceOracle.available == true) {// check the priceOracle is available
                price = _getUnderlyingPriceInternal(_pToken, tokenConfig, priceOracle);
                if (price > 0) {
                    return price;
                }
            }
        }

        // price must bigger than 0
        require(price > 0, "price must bigger than zero");

        return 0;
    }

    function _getUnderlyingPriceInternal(address _pToken, TokenConfig memory tokenConfig, PriceOracle memory priceOracle) internal view returns (uint){

        address underlying = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        PTokenInterface pToken = PTokenInterface(_pToken);

        if (!compareStrings(pToken.symbol(), "pONE")) {
            underlying = address(PTokenInterface(_pToken).underlying());
        }

        PriceOracleType sourceType = priceOracle.sourceType;
        if (sourceType == PriceOracleType.ChainLink) {
            return _getChainlinkPriceInternal(priceOracle, tokenConfig);
        } else if (sourceType == PriceOracleType.Compound) {
            return _getCompoundPriceInternal(priceOracle, tokenConfig);
        } else if (sourceType == PriceOracleType.Customer) {
            return _getCustomerPriceInternal(priceOracle, tokenConfig);
        } else if (sourceType == PriceOracleType.ChainLinkEthBase) {
            return _getChainLinkEthBasePriceInternal(priceOracle, tokenConfig);
        }

        return 0;
    }


    function _getCustomerPriceInternal(PriceOracle memory priceOracle, TokenConfig memory tokenConfig) internal view returns (uint) {
        address source = priceOracle.source;
        WePiggyPriceOracleInterface customerPriceOracle = WePiggyPriceOracleInterface(source);
        uint price = customerPriceOracle.getPrice(tokenConfig.underlying);
        if (price <= 0) {
            return 0;
        } else {//return: (price / 1e8) * (1e36 / baseUnit) ==> price * 1e28 / baseUnit
            return uint(price).mul(1e28).div(tokenConfig.baseUnit);
        }
    }

    // Get price from compound oracle
    function _getCompoundPriceInternal(PriceOracle memory priceOracle, TokenConfig memory tokenConfig) internal view returns (uint) {
        address source = priceOracle.source;
        CompoundPriceOracleInterface compoundPriceOracle = CompoundPriceOracleInterface(source);
        CompoundPriceOracleInterface.CTokenConfig memory ctc = compoundPriceOracle.getTokenConfigBySymbol(tokenConfig.underlyingSymbol);
        address cTokenAddress = ctc.cToken;
        return compoundPriceOracle.getUnderlyingPrice(cTokenAddress);
    }


    // Get price from chainlink oracle
    function _getChainlinkPriceInternal(PriceOracle memory priceOracle, TokenConfig memory tokenConfig) internal view returns (uint){

        require(tokenConfig.baseUnit > 0, "baseUnit must be greater than zero");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceOracle.source);
        (,int price,,,) = priceFeed.latestRoundData();

        if (price <= 0) {
            return 0;
        } else {//return: (price / 1e8) * (1e36 / baseUnit) ==> price * 1e28 / baseUnit
            return uint(price).mul(1e28).div(tokenConfig.baseUnit);
        }

    }

    // base chainlink: token-ETH-USD
    function _getChainLinkEthBasePriceInternal(PriceOracle memory priceOracle, TokenConfig memory tokenConfig) internal view returns (uint){
        require(tokenConfig.baseUnit > 0, "baseUnit must be greater than zero");

        address token = tokenConfig.underlying;
        AggregatorV3Interface tokenEthPriceFeed = AggregatorV3Interface(chainLinkTokenEthPriceFeed[token]);
        (,int tokenEthPrice,,,) = tokenEthPriceFeed.latestRoundData();

        AggregatorV3Interface ethUsdPriceFeed = AggregatorV3Interface(ethUsdPriceFeedAddress);
        (,int ethUsdPrice,,,) = ethUsdPriceFeed.latestRoundData();

        if (tokenEthPrice <= 0) {
            return 0;
        } else {// tokenEthPrice/1e18 * ethUsdPrice/1e8 * 1e36 / baseUnit
            return uint(tokenEthPrice).mul(uint(ethUsdPrice)).mul(1e10).div(tokenConfig.baseUnit);
        }
    }

    function addTokenConfig(address pToken, address underlying, string memory underlyingSymbol, uint256 baseUnit, bool fixedUsd,
        address[] memory sources, PriceOracleType[] calldata sourceTypes) public onlyOwner {

        require(sources.length == sourceTypes.length, "sourceTypes.length must equal than sources.length");

        // add TokenConfig
        TokenConfig storage tokenConfig = tokenConfigs[pToken];
        require(tokenConfig.pToken == address(0), "bad params");
        tokenConfig.pToken = pToken;
        tokenConfig.underlying = underlying;
        tokenConfig.underlyingSymbol = underlyingSymbol;
        tokenConfig.baseUnit = baseUnit;
        tokenConfig.fixedUsd = fixedUsd;

        // add priceOracles
        require(oracles[pToken].length < 1, "bad params");
        for (uint i = 0; i < sources.length; i++) {
            PriceOracle[] storage list = oracles[pToken];
            list.push(PriceOracle({
            source : sources[i],
            sourceType : sourceTypes[i],
            available : true
            }));
        }

        emit ConfigUpdated(pToken, underlying, underlyingSymbol, baseUnit, fixedUsd);
        emit PriceOracleUpdated(pToken, oracles[pToken]);

    }

    function addOrUpdateTokenConfigSource(address pToken, uint256 index, address source, PriceOracleType _sourceType, bool available) public onlyOwner {

        PriceOracle[] storage list = oracles[pToken];

        if (list.length > index) {//will update
            PriceOracle storage oracle = list[index];
            oracle.source = source;
            oracle.sourceType = _sourceType;
            oracle.available = available;
        } else {//will add
            list.push(PriceOracle({
            source : source,
            sourceType : _sourceType,
            available : available
            }));
        }

    }

    function updateTokenConfigBaseUnit(address pToken, uint256 baseUnit) public onlyOwner {
        TokenConfig storage tokenConfig = tokenConfigs[pToken];
        require(tokenConfig.pToken != address(0), "bad params");
        tokenConfig.baseUnit = baseUnit;

        emit ConfigUpdated(pToken, tokenConfig.underlying, tokenConfig.underlyingSymbol, baseUnit, tokenConfig.fixedUsd);
    }

    function updateTokenConfigFixedUsd(address pToken, bool fixedUsd) public onlyOwner {
        TokenConfig storage tokenConfig = tokenConfigs[pToken];
        require(tokenConfig.pToken != address(0), "bad params");
        tokenConfig.fixedUsd = fixedUsd;

        emit ConfigUpdated(pToken, tokenConfig.underlying, tokenConfig.underlyingSymbol, tokenConfig.baseUnit, fixedUsd);
    }

    function setEthUsdPriceFeedAddress(address feedAddress) public onlyOwner {
        ethUsdPriceFeedAddress = feedAddress;
    }

    function addOrUpdateChainLinkTokenEthPriceFeed(address[] memory tokens, address[] memory chainLinkTokenEthPriceFeeds) public onlyOwner {

        require(tokens.length == chainLinkTokenEthPriceFeeds.length, "tokens.length must equal than chainLinkTokenEthPriceFeeds.length");

        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            chainLinkTokenEthPriceFeed[token] = chainLinkTokenEthPriceFeeds[i];
        }

    }


    function getOracleSourcePrice(address pToken, uint sourceIndex) public view returns (uint){

        TokenConfig storage tokenConfig = tokenConfigs[pToken];
        PriceOracle[] storage priceOracles = oracles[pToken];

        return _getUnderlyingPriceInternal(pToken, tokenConfig, priceOracles[sourceIndex]);
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function oracleLength(address pToken) public view returns (uint){
        PriceOracle[] storage priceOracles = oracles[pToken];
        return priceOracles.length;
    }

}