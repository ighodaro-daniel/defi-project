

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @notice what are our invariant
 *  1. the total supply of Dsc should be less than our total value of collateral
 * 2. getter view function should never revert
 */
import {Test,console} from 'forge-std/Test.sol';
import {StdInvariant} from 'forge-std/StdInvariant.sol';
import {DecentralisedStableCoin} from '../../src/DecentralisedStableCoin.sol';
import {DSCEngine} from '../../src/DSCEngine.sol';
import {HelperConfig} from '../../script/HelperConfig.s.sol';
import {DeployDecenStableCoin} from '../../script/DeployDecenStableCoin.s.sol';
import {ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
import{HandlerTest} from '../fuzz/HandlerTest.t.sol';
import{IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
contract OpenInvariantTest is StdInvariant,Test{
DeployDecenStableCoin deployer;
DSCEngine dscEngine;
HelperConfig helperConfig;
DecentralisedStableCoin dsc;
address weth;
address wbtc;
HandlerTest handler;
    function setUp() external{
        deployer = new DeployDecenStableCoin();
        (dscEngine,dsc,helperConfig) = deployer.run();
        (,,weth,wbtc,) = helperConfig.activeNetworkConfig();
        handler = new HandlerTest(dsc,dscEngine);
        targetContract(address(handler));

    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view{
    uint256 totalSupply = dsc.totalSupply();
    uint256 wethDeposited = IERC20(weth).balanceOf(address(dscEngine));
    uint256 wbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

    uint256 wethValue = dscEngine.getUsdValue(weth,wethDeposited);
    uint256 wbtcValue = dscEngine.getUsdValue(wbtc,wbtcDeposited);
    uint256 totalCollateral = wethValue + wbtcValue;
    console.log('weth value ======>',wethValue);
    console.log('wbtc value ======>',wbtcValue);
    console.log('total supply',totalSupply);
    console.log('total collateral',totalCollateral);
    console.log('time mint is called =====>', handler.timesMintIscalled());
    console.log('collateral half', handler.collateralHalf());
    console.log('max dsc minted', handler.maxDscToMint());
    console.log('total dsc minted ===>', handler.totalDscMinted());
    console.log('collateral in usd ===>',handler.collateralValueInUsd());
    assert( totalCollateral >= totalSupply);
    }
  function inVariant_getterShouldNotRevert() public view{
    dscEngine.getLiquidationBonus();
    dscEngine.getPrecisionPrice();
  }
}
