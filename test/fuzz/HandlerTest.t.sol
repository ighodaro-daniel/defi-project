//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import{Test,console} from  'forge-std/Test.sol';
import{DecentralisedStableCoin} from '../../src/DecentralisedStableCoin.sol';
import{DSCEngine} from '../../src/DSCEngine.sol';
import{ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
import {MockV3Aggregator} from  '../../test/mock/MockV3Aggregator.t.sol';
contract HandlerTest is Test{
    DecentralisedStableCoin dsc;
    DSCEngine dscEngine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256  public MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public timesMintIscalled;
    address[] public userWithCollateralDeposited;
    int256  public collateralHalf;
int256  public maxDscToMint;
uint256 public totalDscMinted;
 
uint256 public  collateralValueInUsd;
MockV3Aggregator public ethUsdPriceFeed;

    constructor(DecentralisedStableCoin _dsc, DSCEngine _dscEngine){
        dsc = _dsc;
        dscEngine = _dscEngine;
        address[] memory collateralTokens = dscEngine.getCollateralToken();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        ethUsdPriceFeed =  MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));

    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
        if(collateralSeed % 2 == 0){
               return weth;
        } else{
            return wbtc;
        }
    }

    function depositCollateral(uint256 collateralSeed,uint256 collateralAmount) public{
            ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
            vm.startPrank(msg.sender);
            collateralAmount = bound(collateralAmount,1,MAX_DEPOSIT_SIZE);
            collateral.mint(msg.sender,collateralAmount);
            
            collateral.approve(address(dscEngine),collateralAmount);
            
            dscEngine.depositCollateral(address(collateral),collateralAmount);
            userWithCollateralDeposited.push(msg.sender);
            vm.stopPrank();
    } 
   
    


       function mint(uint256 amount,uint256 addressSeed) public{
        if(userWithCollateralDeposited.length == 0){
            return;
        }
      address sender = userWithCollateralDeposited[addressSeed % userWithCollateralDeposited.length];
    ( totalDscMinted ,  collateralValueInUsd) = dscEngine.getAccountInformation(sender);
      collateralHalf = (int256(collateralValueInUsd)/2);
     maxDscToMint = collateralHalf - int256(totalDscMinted);
    
    
    if (maxDscToMint < 0){
        return;
    }
    amount = bound(amount, 0, uint256(maxDscToMint));
    
    if (amount== 0){
        return;
    }
    vm.startPrank(sender);
    dscEngine.mintDsc(amount);
    vm.stopPrank();
    timesMintIscalled++;
}

     

     function redeemCollateral(uint256 collateralSeed,uint256 collateralAmount) public{
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxAmountToRedeem = dscEngine.getCollateralDeposited(address(collateral),msg.sender);
        collateralAmount = bound(collateralAmount,0,maxAmountToRedeem);
        if (collateralAmount == 0){
            return;
        }
        dscEngine.redeemedCollateral(address(collateral),collateralAmount);

     }


    /**  function updateCollateralPrice(uint96 newPrice) public {
        int256 newInt = int256(uint256(newPrice));
        ethUsdPriceFeed.updateAnswer(newInt);
     }*/
    

}
    