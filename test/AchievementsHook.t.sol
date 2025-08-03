// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import {Test} from "forge-std/Test.sol";
 
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
 
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
 
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
 
import "forge-std/console.sol";
import {AchievementsHook} from "../src/AchievementsHook.sol";
 
contract TestAchievementsHook is Test, Deployers, ERC1155TokenReceiver {
	MockERC20 token; // our token to use in the ETH-TOKEN pool
 
	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;
 
	AchievementsHook hook;
 
	function setUp() public {
		// Step 1 + 2
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();
    
        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));
    
        // Mint a bunch of TOKEN to ourselves and to address(1)
        token.mint(address(this), 10000 ether);
        token.mint(address(1), 10000 ether);
    
        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo("AchievementsHook.sol", abi.encode(manager), address(flags));
    
        // Deploy our hook
        hook = AchievementsHook(address(flags));
    
        // Approve our TOKEN for spending on the swap router and modify liquidity router
        // These variables are coming from the `Deployers` contract
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);
    
        // Initialize a pool
        (key, ) = initPool(
            ethCurrency, // Currency 0 = ETH
            tokenCurrency, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
        );
    
        // Add some liquidity to the pool
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);
    
        uint256 ethToAdd = 30 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper,
            ethToAdd
        );
    
        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
	}

    function test_swap_1_eth_twice() public {    
        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));
    
        // We will swap 1 ether for tokens
        // We should get 1 achievement for 1 eth swap volume 
        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -1 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        uint256 balanceAfterSwap = hook.balanceOf(
            address(this),
            1
        );
        assertEq(balanceAfterSwap, 1);

        (uint256 weiVolume, uint8 counter) = hook.swapVolume(address(this));
        assertEq(weiVolume, 1 ether);
        assertEq(counter, 1);

        // Make the same swap again
        // Ensure there is no double minting for specific achievement
        swapRouter.swap{value: 1 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -1 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        balanceAfterSwap = hook.balanceOf(
            address(this),
            1
        );
        assertEq(balanceAfterSwap, 1);

        balanceAfterSwap = hook.balanceOf(
            address(this),
            2
        );
        assertEq(balanceAfterSwap, 1);

        (weiVolume, counter) = hook.swapVolume(address(this));
        assertEq(weiVolume, 2 ether);
        assertEq(counter, 2);
    }

    function test_swap_3_eth() public {    
        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));
    
        // We will swap 3 ether for tokens
        // We should get 3 achievements (for 1, 2 and 3 eth volume reached in total) 
        swapRouter.swap{value: 3 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -3 ether, // Exact input for output swap
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        (uint256 weiVolume, uint8 counter) = hook.swapVolume(address(this));
        assertEq(weiVolume, 3 ether);
        assertEq(counter, 3);

        uint256 balanceAfterSwap = hook.balanceOf(
            address(this),
            1 // total ETH volume in the pool
        );
        assertEq(balanceAfterSwap, 1);

        balanceAfterSwap = hook.balanceOf(
            address(this),
            2 // total ETH volume in the pool
        );
        assertEq(balanceAfterSwap, 1);

        balanceAfterSwap = hook.balanceOf(
            address(this),
            3 // total ETH volume in the pool
        );
        assertEq(balanceAfterSwap, 1);
    }
}
