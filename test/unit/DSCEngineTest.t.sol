// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import {Test,console} from 'forge-std/Test.sol';
import{DSCEngine} from '../../src/DSCEngine.sol';
import{DeployDecenStableCoin} from '../../script/DeployDecenStableCoin.s.sol';
import{DecentralisedStableCoin} from '../../src/DecentralisedStableCoin.sol';
import{HelperConfig} from  '../../script/HelperConfig.s.sol';
import{ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
contract DSCEngineTest is Test{
    DecentralisedStableCoin dsc;
    DeployDecenStableCoin deployer;
    DSCEngine   dscEngine;
    HelperConfig helperConfig;
    uint256 public  constant PRECISION_PRICE = 1e18;
    uint256 public constant AMOUNT = 15e18;
    uint256 public constant COLLATERAL_AMOUNT = 2000e18;
    uint256 public constant STARTING_ERC20_BALANCE = 10000 ether;
    uint256 public  constant ADDITIONAL_PRICE = 1e10;
    uint256 public constant MINT_AMOUNT = 3900e18;
   address  wethAddress;
   address  wethUsdPriceAddress ;
   address  wbtcUsdPriceAddress;
   address wbtcAddress;
   address USER = makeAddr('user');
   address [] tokenAddresses;
   address[] priceAdddresses;

    function setUp() external{
        deployer = new DeployDecenStableCoin();
        ( dscEngine,dsc,helperConfig) = deployer.run();
       (  wethUsdPriceAddress,wbtcUsdPriceAddress,wethAddress,wbtcAddress,) = helperConfig.activeNetworkConfig();
       ERC20Mock(wethAddress).mint(USER,STARTING_ERC20_BALANCE);
    }



   ////////////////////////
   // constructor test //
   //////////////////////
   function testAddressesMustbeOfTheSameLength()public{
       tokenAddresses = [wbtcAddress];
       priceAdddresses =[wethUsdPriceAddress,wbtcUsdPriceAddress];
       vm.expectRevert(DSCEngine.DscEngine_tokenAndPriceFeedAddressMustBeTheSameLength.selector);
       new DSCEngine(tokenAddresses,priceAdddresses,address(dsc));

   }


   function testGetTokenAmountFromUsd() public view {
    uint256 usdAmount = 100 ether;
    uint256 expectedAmount = 0.05 ether;
    uint256 actualAmount = dscEngine.getTokenAmountFromUsd(wethAddress,usdAmount);
    assert(expectedAmount == actualAmount);

   }
    function testRevertDepositCollateral() public{
       vm.startPrank(USER);
       //vm.deal(USER,400 ether);
       ERC20Mock(wethAddress).approve(USER,10 ether);
       vm.expectRevert(DSCEngine.Deposit_MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(wethAddress,0);
        vm.stopPrank();
    }



function testRevertTokenwithUnapprovedCollateral() public {
    ERC20Mock ranToken = new ERC20Mock('RAN','RAN',USER,COLLATERAL_AMOUNT);
     vm.startPrank(USER);
     vm.expectRevert(DSCEngine.tokenAddress_notAllowedForCollateral.selector);
     dscEngine.depositCollateral(address(ranToken), COLLATERAL_AMOUNT );
     vm.stopPrank();

}

function testCanDepositCollateral() public{
    vm.startPrank(USER);
    ERC20Mock(wethAddress).approve(address(dscEngine),COLLATERAL_AMOUNT);
    dscEngine.depositCollateral(wethAddress,COLLATERAL_AMOUNT);
    uint256 expectedAmount = dscEngine.getCollateralDeposited(USER,wethAddress);
    vm.stopPrank();
    console.log('expected amount ==========> ',expectedAmount);
    assert(COLLATERAL_AMOUNT == expectedAmount);
    
}

modifier depositTested{
    vm.startPrank(USER);
    ERC20Mock(wethAddress).approve(address(dscEngine), COLLATERAL_AMOUNT);
    dscEngine.depositCollateral(wethAddress,COLLATERAL_AMOUNT);
    vm.stopPrank();
    _;
}

function testCanDepositAndGetAccountInformation() public  depositTested{
    ( uint256 totalDscMinted,  uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
    uint256 expectedDscMinted = 0;
    uint256 expectedCollateralValueInUsd = dscEngine.getTokenAmountFromUsd(wethAddress,collateralValueInUsd);
    assertEq(totalDscMinted,expectedDscMinted);
    assertEq(COLLATERAL_AMOUNT,expectedCollateralValueInUsd);
}
function testDepositCollateralAndMintDsc() public{
    vm.startPrank(USER);
    uint256 amount = 400 ether;
    ERC20Mock(wethAddress).approve(address(dscEngine),STARTING_ERC20_BALANCE);
    dscEngine.depositCollateralAndMintDsc(wethAddress,STARTING_ERC20_BALANCE, amount);
    uint256 expectedDscMinted = dscEngine.getAmountDscMinted();
    vm.stopPrank();
    assertEq(amount,expectedDscMinted); 
}

function testGetAccountInformation() public {
      vm.startPrank(USER);
    uint256 amount = 400 ether;
    ERC20Mock(wethAddress).approve(address(dscEngine),STARTING_ERC20_BALANCE);
     dscEngine.depositCollateralAndMintDsc(wethAddress,STARTING_ERC20_BALANCE, amount);
     console.log(dscEngine.getHealthFactor(USER));


}
function testRedeemCollateral() public depositTested{
    vm.startPrank(USER);

    // Get the initial balance of the user before redeeming collateral
    uint256 initialUserBalance = ERC20Mock(wethAddress).balanceOf(USER);
    uint256 initialContractBalance = ERC20Mock(wethAddress).balanceOf(address(dscEngine));
    uint256 initialCollateralDeposited = dscEngine.getCollateralDeposited(USER,wethAddress);

    // Call the redeemCollateral function
    dscEngine.redeemedCollateral(wethAddress, COLLATERAL_AMOUNT);


    vm.stopPrank();
    uint256 expectedCollateralDeposited = initialCollateralDeposited - COLLATERAL_AMOUNT;
    console.log(initialUserBalance);
    console.log(expectedCollateralDeposited);
   assertEq(dscEngine.getCollateralDeposited(USER,wethAddress), expectedCollateralDeposited);

    uint256 expectedUserBalance = initialUserBalance + COLLATERAL_AMOUNT;
    console.log(expectedUserBalance);
    //assertEq(ERC20Mock(wethAddress).balanceOf(USER), expectedUserBalance);

   /** 
    *  // Check that the collateral deposited was reduced
   

    // Check that the user's balance increased by the redeemed amount
    uint256 expectedUserBalance = initialUserBalance + COLLATERAL_AMOUNT;
    assertEq(ERC20Mock(wethAddress).balanceOf(USER), expectedUserBalance);

    // Check that the contract's balance decreased by the redeemed amount
    uint256 expectedContractBalance = initialContractBalance - COLLATERAL_AMOUNT;
    assertEq(ERC20Mock(wethAddress).balanceOf(address(dscEngine)), expectedContractBalance);
    */
}
function testGetUsdValues() public view  {
    // Mock data
    uint256 amountInTokens = 15e18; // 15 tokens
    uint256 pricePerToken = 2000e8; // $2000 per token in 8 decimal places

    // Calculate the expected USD value
    uint256 expectedUsdValue = ((pricePerToken *dscEngine.getAdditionalPrice() ) * amountInTokens) / dscEngine.getPrecisionPrice();

    // Get the actual USD value from the DSCEngine contract
    uint256 actualUsdValue = dscEngine.getUsdValue(wethAddress, amountInTokens);

    // Assert that the expected value matches the actual value
    assertEq(expectedUsdValue, actualUsdValue);
}

function testFullRedemption() public depositTested {
    vm.startPrank(USER);

    uint256 initialUserBalance = ERC20Mock(wethAddress).balanceOf(USER);
    dscEngine.redeemedCollateral(wethAddress, COLLATERAL_AMOUNT);

    uint256 expectedUserBalance = initialUserBalance + COLLATERAL_AMOUNT;
    assertEq(ERC20Mock(wethAddress).balanceOf(USER), expectedUserBalance);
    assertEq(dscEngine.getCollateralDeposited(USER, wethAddress), 0);

    vm.stopPrank();
}

function testHealthFactorCalculation() public {
    uint256 totalDscMinted = 0;
    uint256 collateralValueInUsd = 1000 ether;

    // When no DSC is minted, the health factor should be max.
    uint256 healthFactor = dscEngine.calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    assertEq(healthFactor, type(uint256).max);

    // Test with some DSC minted
    totalDscMinted = 500 ether;
    healthFactor = dscEngine.calculateHealthFactor(totalDscMinted, collateralValueInUsd);

    // Manual calculation
    uint256 expectedHealthFactor = (collateralValueInUsd * dscEngine.getLiquidationThreshold() / dscEngine.getLiquidationPrecision() ) * dscEngine.getPrecisionPrice() / totalDscMinted;

    assertEq(healthFactor, expectedHealthFactor);
}

/**function testRevertMintDscWithInsufficientCollateral() public  {
    
   // Amount of DSC to mint

    // Start prank with the user account
    vm.startPrank(USER);
     
    // Approve and deposit the insufficient collateral
    ERC20Mock(wethAddress).approve(address(dscEngine), COLLATERAL_AMOUNT);
    dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
    vm.expectRevert(DSCEngine.DSCEngine_InsufficientCollateral.selector); 
    dscEngine.mintDsc(MINT_AMOUNT);
    vm.stopPrank();
}
**/

}

