pragma solidity 0.6.12;

import "./WePiggyPriceOracleInterface.sol";
import "../token/ERC20Interface.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

contract WePiggyPriceOracleV1 is WePiggyPriceOracleInterface, OwnableUpgradeSafe {

    using SafeMath for uint256;

    ///@notice The fundamental unit of storage for a reporter source
    struct Datum {
        uint256 timestamp;
        uint256 value;
    }

    struct TokenConfig {
        address token;
        string symbol;
        uint upperBoundAnchorRatio; //1.2e8
        uint lowerBoundAnchorRatio; //0.8e8
    }

    mapping(address => Datum) private data;
    mapping(address => TokenConfig) public configs;
    uint internal constant minLowerBoundAnchorRatio = 0.8e8;
    uint internal constant maxUpperBoundAnchorRatio = 1.2e8;

    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice The event emitted when the stored price is updated
    event PriceUpdated(address token, uint price);
    event ConfigUpdated(address token, string symbol, uint upperBoundAnchorRatio, uint lowerBoundAnchorRatio);

    function initialize() public initializer {
        OwnableUpgradeSafe.__Ownable_init();
    }

    function getPrice(address token) external override(WePiggyPriceOracleInterface) view returns (uint){
        Datum storage datum = data[token];
        return datum.value;
    }

    function setPrice(address token, uint price, bool force) external override(WePiggyPriceOracleInterface) onlyOwner {

        Datum storage datum = data[token];
        if (force) {
            datum.value = price;
            datum.timestamp = block.timestamp;
        } else {
            TokenConfig storage config = configs[token];
            require(config.token == token, "bad params");

            uint upper = datum.value.mul(config.upperBoundAnchorRatio);
            uint lower = datum.value.mul(config.lowerBoundAnchorRatio);
            uint newPrice = price.mul(1e8);

            require(newPrice.sub(lower) >= 0, "the price must greater than the old*lowerBoundAnchorRatio");
            require(newPrice.sub(upper) <= 0, "the price must less than the old*upperBoundAnchorRatio");

            datum.value = price;
            datum.timestamp = block.timestamp;
        }


        emit PriceUpdated(token, price);

    }

    function setTokenConfig(address token, string memory symbol, uint upperBoundAnchorRatio, uint lowerBoundAnchorRatio) public onlyOwner {

        require(minLowerBoundAnchorRatio <= lowerBoundAnchorRatio, "lowerBoundAnchorRatio must greater or equal to minLowerBoundAnchorRatio");
        require(maxUpperBoundAnchorRatio >= upperBoundAnchorRatio, "upperBoundAnchorRatio must Less than or equal to maxUpperBoundAnchorRatio");

        TokenConfig storage config = configs[token];

        config.token = token;
        config.symbol = symbol;
        config.upperBoundAnchorRatio = upperBoundAnchorRatio;
        config.lowerBoundAnchorRatio = lowerBoundAnchorRatio;

        emit ConfigUpdated(token, symbol, upperBoundAnchorRatio, lowerBoundAnchorRatio);

    }

}
