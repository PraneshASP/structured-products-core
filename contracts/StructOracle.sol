pragma solidity >=0.6.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IStructOracle.sol";

/**
 * @title StructOracle
 * @notice Used as price feed for fetching realtime prices
 */
contract StructOracle is IStructOracle {
    AggregatorV3Interface internal ethPriceFeed;

    constructor(address ethDataFeed) public {
        ethPriceFeed = AggregatorV3Interface(ethDataFeed);
    }

    /**
     *@dev Returns the latest ETH price
     */
    function getLatestETHPrice() public view override returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = ethPriceFeed.latestRoundData();
        return uint256(price) * 10**10;
    }
}
