

//SPDX-License-Identifier: MIT

//pragma solidity ^0.8.19;

/**
 * @notice what are our invariant
 *  1. the total supply of Dsc should be less than our total value of collateral
 * 2. getter view function should never revert
 
import {Test,console} from 'forge-std/Test.sol';
import {StdInvariant} from 'forge-std/StdInvariant.sol';
import {DecentralisedStableCoin} from '../../src/DecentralisedStableCoin.sol';
import {DSCEngine} from '../../src/DSCEngine.sol';
import {HelperConfig} from '../../script/HelperConfig.s.sol';
import {DeployDecenStableCoin} from '../../script/DeployDecenStableCoin.s.sol';
import {ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
contract OpenInvariantTest is StdInvariant,Test{
DeployDecenStableCoin deployer;
DSCEngine dscEngine;
HelperConfig helperConfig;
DecentralisedStableCoin dsc;
address weth;
address wbtc;

    function setUp() external{
        deployer = new DeployDecenStableCoin();
        (dscEngine,dsc,helperConfig) = deployer.run();
        (,,weth,wbtc,) = helperConfig.activeNetworkConfig();
         targetContract(address(dscEngine));

    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view{
    uint256 totalSupply = dsc.totalSupply();
    uint256 wethDeposited = ERC20Mock(weth).balanceOf(address(dscEngine));
    uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dscEngine));

    uint256 wethValue = dscEngine.getUsdValue(weth,wethDeposited);
    uint256 wbtcValue = dscEngine.getUsdValue(wbtc,wbtcDeposited);
    console.log('weth value ======>',wethValue);
    console.log('wbtc value ======>',wbtcValue);
    assert(wethValue + wbtcValue >= totalSupply);
    }

}
*/