//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import {Script} from 'forge-std/Script.sol';
import{MockV3Aggregator} from '../test/mock/MockV3Aggregator.t.sol';
import{ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
//import {CustomERC20Mock} from '../script/CustomERC20Mock.s.sol';
contract HelperConfig is Script{

    struct NetworkConfig{
          address wethUsdPriceFeed;
          address wbtcUsdPriceFeed;
          address weth;
          address wbtc;
          uint256 deployerKey;
    }
uint8 public constant DECIMAL = 8;
int256 public constant ETH_USD_PRICE = 2000e8;
int256 public constant BTC_USD_PRICE = 1000e8;
uint256 public constant DEFAULT_KEY = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;
NetworkConfig public activeNetworkConfig;


constructor(){
    if (block.chainid == 11155111){
        activeNetworkConfig = getSepoliaWrappedToken();
    } else{
        activeNetworkConfig = getAnvilWrappedToken();
    }
}
function getSepoliaWrappedToken()public view returns(NetworkConfig memory){
    return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });

} 
function getAnvilWrappedToken() public  returns(NetworkConfig memory){
    if(activeNetworkConfig.wethUsdPriceFeed != address(0)){
        return activeNetworkConfig;
    }
    vm.startBroadcast();
    MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMAL,ETH_USD_PRICE);

    ERC20Mock weth = new ERC20Mock('WETH','WETH',msg.sender, 1000e8);

    MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMAL,BTC_USD_PRICE);

    ERC20Mock wbtc = new ERC20Mock('WBTC','WBTC',msg.sender, 1000e8);
    vm.stopBroadcast();
   
    return NetworkConfig({
         wethUsdPriceFeed:address(ethUsdPriceFeed),
         wbtcUsdPriceFeed: address(btcUsdPriceFeed),
         weth:address(weth),
         wbtc: address(wbtc),
         deployerKey: DEFAULT_KEY
         //vm.envUint('ANVIL_DEFAULT_KEY')
    });

}




}
