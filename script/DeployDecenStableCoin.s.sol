//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import{Script} from 'forge-std/Script.sol';
import{DSCEngine} from '../src/DSCEngine.sol';
import{DecentralisedStableCoin} from '../src/DecentralisedStableCoin.sol';
import {HelperConfig} from '../script/HelperConfig.s.sol';

contract DeployDecenStableCoin is Script{
DSCEngine dscEngine;
DecentralisedStableCoin dsc;
HelperConfig helperConfig;
address []  public tokenAddress;
address [] priceFeedAddress;
function run() external returns(DSCEngine,DecentralisedStableCoin,HelperConfig){
     
    
    helperConfig = new HelperConfig();
    
    ( address wethUsdPriceFeed,address wbtcUsdPriceFeed,address weth, address wbtc,uint256 deployerKey) = helperConfig.activeNetworkConfig();
     tokenAddress =[weth,wbtc];
     priceFeedAddress = [wethUsdPriceFeed,wbtcUsdPriceFeed];

     vm.startBroadcast(deployerKey);
     dsc = new DecentralisedStableCoin();

    dscEngine = new DSCEngine(tokenAddress,priceFeedAddress,address(dsc));

    dsc.transferOwnership(address(dscEngine));
    vm.stopBroadcast();
     return (dscEngine, dsc,helperConfig);
}

}