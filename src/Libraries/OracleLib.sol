//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title Oracle Lib 
 * @author Daniel ighodaro
 * @notice this library is used to check the chainlink oracle for stale price data
 * if the price is stale , the function will revert and the dscEngine unuseable
 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
library OracleLib{
error OracleLib_StalePrice();

uint256 public constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData( AggregatorV3Interface priceFeed)public view returns(uint80, int256 , uint256 , uint256 , uint80){
          
       (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
      uint256 secondSince = block.timestamp - updatedAt;

      if(secondSince > TIMEOUT){
        revert OracleLib_StalePrice();
      }
      else{
      return (roundId,answer,startedAt,updatedAt,answeredInRound);
      }
    }

}