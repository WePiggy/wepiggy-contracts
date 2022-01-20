pragma solidity ^0.6.0;

pragma experimental ABIEncoderV2;

interface IRequesterView
{
    function getLastUpdate(string calldata priceType, address dataSource) external view returns (uint256 timestamp);
    function get(string calldata priceTypes, address dataSources) external view returns (uint256 value, uint256 timestamp);
    function latestRoundData(string calldata priceType, address dataSource) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

