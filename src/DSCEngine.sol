//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
/**
 * @author Daniel Ighodaro
 * @title DSCEngine
 * this system is designe to be as minimal as possible, and have the token
 * maintain a 1token == $1
 * this stablecoin has properties:
 * - Exogenous collateral
 * - Dollar peggged
 * - Algorithmically stable
 * It takes the functionally of Dai, if Dai has no governance, no fees but only backed up by wETH and wBTC
 * @notice This contract is the core of the DSC system, it handles all the logic for minning and redeeming DSC,as well as withdrawing and
 *   depositing collateral
 *   @notice this contract is loosely based on the MakerDAO DSS (DAI) system
 *
 */

import {DecentralisedStableCoin} from "../src/DecentralisedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from '../src/Libraries/OracleLib.sol';
contract DSCEngine is ReentrancyGuard {
    /////////////////
    // custom error//
    ////////////////
    error Deposit_MustBeMoreThanZero();
    error tokenAddress_notAllowedForCollateral();
    error DscEngine_tokenAndPriceFeedAddressMustBeTheSameLength();
    error DSCEngine__transferFailed();
    error DSCEngine__BreaksHealthLimit(uint256);
    error DSCEngine__MintFailed();
    error DSCEngine__redeemedFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine_HealthFactorNotImproved();
    error DSCEngine_InsufficientCollateral();


    //////////////////
    //   type      //
    ////////////////// 

 using OracleLib for AggregatorV3Interface;



    ///////////////////// 
    // state varaible //
    ////////////////////
    mapping(address token => address priceFeed) s_priceFeeds;
    mapping(address user => mapping(address collateralAddress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amount) private s_amountDscMinted;
    DecentralisedStableCoin private immutable i_dsc;
    address [] private s_collateralTokenAddress;


    uint256  public s_totalCollateralValueInUsd;
    uint256 public constant ADDITIONAL_PRECISION_PRICE = 1e10;
    uint256 public constant PRECISION_PRICE = 1e18;
    uint256 public constant LIQUIDATE_THRESHOLD = 50; //200% overcollaterisation
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIMIT_HEALTH = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 10;

    ///////////////////
    // event         //
    /////////////////// 
    event CollateralDeposited(address indexed sender, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);
    ///////////////////
    // modifiers     //
    /////////////////
    modifier _ExceedZero(uint256 amount) {
        if (amount <= 0) {
            revert Deposit_MustBeMoreThanZero();
        }
        _;
    }

    modifier _isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert tokenAddress_notAllowedForCollateral();
        }
        _;
    }

    constructor(address[] memory tokenAddress, address[] memory priceFeedAddress, address dscAddress) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DscEngine_tokenAndPriceFeedAddressMustBeTheSameLength();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokenAddress.push(tokenAddress[i]);
        }
        i_dsc = DecentralisedStableCoin(dscAddress);
    }


    /**  @param tokenCollateralAddress - the address of token to deposit address
     @param collateralAmount - the amount of token deposited as collateral
     @param  amountDscToMint of dsc to be minted 
     @notice the function combined both depositing and minting all at once
     */
    function depositCollateralAndMintDsc(
    address tokenCollateralAddress,
    uint256 collateralAmount,
    uint256 amountDscToMint) public  {
        depositCollateral(tokenCollateralAddress,collateralAmount);
        mintDsc(amountDscToMint);
    }

    function redeemedCollateral(address tokenCollateralAddress, uint256 collateralAmount) public _ExceedZero(collateralAmount) _isAllowedToken(tokenCollateralAddress) nonReentrant {
        _redeemedCollateral(msg.sender,msg.sender,tokenCollateralAddress,collateralAmount);
       _revertIfHealthFactorIsBroken(tokenCollateralAddress);
    }


    // @param collateralToken - the address of the collateral token to deposit
    // @param tokenCollateralAmount - the amount of token deposited as collateral
    function depositCollateral(address collateralToken, uint256 CollateralAmount)
        public
        _ExceedZero(CollateralAmount)
        _isAllowedToken(collateralToken)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][collateralToken] += CollateralAmount;

        emit CollateralDeposited(msg.sender,collateralToken,CollateralAmount);
        bool success = IERC20(collateralToken).transferFrom(msg.sender,address(this),CollateralAmount);
        if(!success){
            revert DSCEngine__transferFailed();
        }
    }


/**
 * 
 * @param tokenCollateralAddress : this is the collateral address to redeemed 
 * @param collateralAmount  this is the amount of collateral to redeemed
 * @param amountDscToBurn this is the amount of token given to be burned
 * @notice this function redeems and burned the dsc in one transaction
 */
    function redeemedCollateralForDsc(address tokenCollateralAddress,
     uint256 collateralAmount,uint256 amountDscToBurn) external {
        redeemedCollateral(tokenCollateralAddress,collateralAmount);// already has health check
        burnDsc(amountDscToBurn);
     }

    function burnDsc(uint256 amount) public {
        _burnDsc(amount,msg.sender,msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); //not such if this works
    }

     /**
      * 
      * @notice follow CEI
      * @param amountDscToMint : amount of dsc token to mint
      * @notice they must have mininimum threshold
      * 
      */
    function mintDsc(uint256 amountDscToMint) public _ExceedZero(amountDscToMint) nonReentrant {
          s_amountDscMinted[msg.sender] += amountDscToMint;
          _revertIfHealthFactorIsBroken(msg.sender);
          bool minted = i_dsc.mintStableCoin(msg.sender,amountDscToMint);
          if(!minted){
            revert DSCEngine__MintFailed();
          }
    }
    
    

       function getTokenAmountFromUsd(address token, uint256 usdAmountInWei ) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
          (, int256 price, , , ) = priceFeed.latestRoundData();
          return (usdAmountInWei * PRECISION_PRICE)/ (uint256(price) * ADDITIONAL_PRECISION_PRICE);
    }

   /**
   
    * 
    * @param collateral -  the erc20 collateral that will be liquidated 
    * @param user - the user who broke the health factor , the heath factor is already below HEALTH_FACTOR minimum
    * @param debtToCover  the amount of DSC you want to burn to improve health factor
    * @notice if we do start nearing undercollateralization , we need someone to liquidate position

    * $100 ETH backing $50 DSC
    * $20 ETH back $50 DSC --> DSC isn't worth $1
    * $75 ETH backing $50 DSC
    * Liquidator takes $75 and burns off $50 DSC 
    * if someone is undercollateralize , we would pay you to liquidate them
    * @notice you would partially liquidate a user
    * @notice you will get rewarded for liquidating a user
    * @notice the function working assume the protocol will be roughly 
    * 200% overcollateralized in other for this to work
    * @notice a known bug would be if the protocol is 100% or less collateralized, then we wouldn't be
    * be able to incentive the liquidator
    * for example, if the price of the collateral plummeted before anyone can be liquidated
    * follow CEI rules: checks, rules, interact
    *
 * @notice we would burn the dsc debt and take their collateral
 * Bad USER = $240 as collateral , 200 as dsc
 * debt to cover = $240
 * $200 of dsc == ?? ETH
 * We would give the liquidator 10% bonus of weth for $200
 * we should implement a feature to liquidate if the protocol is insolvent
 * and sweep extra amount into the treasury
*/
    function liquidate(address collateral, 
    address user, 
    uint256 debtToCover) external _ExceedZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= LIMIT_HEALTH){
            revert DSCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral,debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS ) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = bonusCollateral + tokenAmountFromDebtCovered;

        _redeemedCollateral(user, msg.sender,collateral, totalCollateralToRedeem);
        _burnDsc(debtToCover,user,msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor){
            revert DSCEngine_HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

 function getAccountCollateralValue(address user) public  view returns( uint256 totalCollateralValueInUsd ) {
         //loop through each collateral address,map it to the price to get the usd

          for (uint256 i = 0; i < s_collateralTokenAddress.length; i++) {
        address token = s_collateralTokenAddress[i];
        uint256 amount = s_collateralDeposited[user][token];
        totalCollateralValueInUsd += _getUsdValue(token, amount);
    }
    return totalCollateralValueInUsd;
    }




    function getHealthFactor(address user) external  returns(uint256){
        return _healthFactor( user);
    }


    ///////////////////////////
    // internal view function //
    ///////////////////////////

    
function _getAccountInformation(address user) private view
  returns(
    uint256 totalDscMinted, uint256 collateralValueInUsd
    ){
        totalDscMinted = s_amountDscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
  
}

    function _healthFactor(address user ) private view returns(uint256 ){
        // total DSC minted
        // total collateral value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        //
        return   _calculateHealthFactor(totalDscMinted,collateralValueInUsd);
       
    }
function _calculateHealthFactor( uint256 totalDscMinted,uint256 collateralValueInUsd) internal pure returns(uint256){
    if(totalDscMinted == 0) return type(uint256).max;
    uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATE_THRESHOLD)/ LIQUIDATION_PRECISION;
         return (collateralAdjustedForThreshold * PRECISION_PRICE)/totalDscMinted;

}
  function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd) public returns(uint256){
    return _calculateHealthFactor(totalDscMinted,collateralValueInUsd);
  }
     

    function _revertIfHealthFactorIsBroken(address user) internal view{
        // check the health factor - collateral must be more than Decentralised stable coin
        //revert if it health factor is down
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < LIMIT_HEALTH){
            revert DSCEngine__BreaksHealthLimit(userHealthFactor);
        }

    }

    

    function _redeemedCollateral(address from, address to,address tokenCollateralAddress,uint256 collateralAmount) private{
         s_collateralDeposited[from][tokenCollateralAddress] -= collateralAmount;
        emit CollateralRedeemed(from, to,tokenCollateralAddress,collateralAmount);
        (bool success) = IERC20(tokenCollateralAddress).transfer(to,collateralAmount);
       if (!success){
        revert  DSCEngine__redeemedFailed();
       }
    }

    /**
     * 
     * @dev low level function, don't call unless the function calling it
     *  is checking for health factor being broken
     */
function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
    s_amountDscMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom,address(this),amountDscToBurn);
        if(!success){
            revert DSCEngine__transferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    
    }

    /////////////////////////////////
    // public & external function //
    /////////////////////////////////

    function _getUsdValue(address token,uint256 amount) private view returns(uint256){
          AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
          (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
          return ((uint256(price) * ADDITIONAL_PRECISION_PRICE ) * amount) / PRECISION_PRICE;
    }
   function getUsdValue(address token, uint256 amount) public view returns (uint256) {
       return _getUsdValue(token,amount);
   }
 
function getCollateralDeposited(address user,address token) public view returns(uint256){
    return s_collateralDeposited[user][token];
}
 function getAccountInformation(address user) external  returns(  uint256 totalDscMinted, uint256 collateralValueInUsd){
    ( totalDscMinted,  collateralValueInUsd) = _getAccountInformation(user);
 }

 function getAmountDscMinted()public view returns(uint256){
   return s_amountDscMinted[msg.sender];
 }


 function getCollateralToken() public view returns(address[] memory ){
    return s_collateralTokenAddress;
 }

 function getAdditionalPrice() public view returns(uint256){
    return ADDITIONAL_PRECISION_PRICE;
 }


 function getPrecisionPrice()public view returns(uint256){
    return PRECISION_PRICE;
 }


 function getLiquidationPrecision() public pure returns(uint256){
     return LIQUIDATION_PRECISION;
 }

 function getLiquidationThreshold() public pure returns(uint256){
    return LIQUIDATE_THRESHOLD;
 }

 function getLiquidationBonus() public pure returns(uint256){
    return LIQUIDATION_BONUS;
 }


function getCollateralTokenPriceFeed(address token) public view returns(address){
      return s_priceFeeds[token];
}

}
