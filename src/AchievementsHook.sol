// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract AchievementsHook is BaseHook, ERC1155 {
    struct Achievements {
        uint256 weiVolume;
        uint8 achievementsCounter;
    }

    mapping(address => Achievements) public swapVolume;

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    // Set up hook permissions to return `true`
    // for the two hook functions we are using
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Implement the ERC1155 `uri` function
    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        // We only mint achievements if user is buying TOKEN with ETH
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // Mint achievements equal to 20% of the amount of ETH they spent
        // Since its a zeroForOne swap:
        // if amountSpecified < 0:
        //      this is an "exact input for output" swap
        //      amount of ETH they spent is equal to |amountSpecified|
        // if amountSpecified > 0:
        //      this is an "exact output for input" swap
        //      amount of ETH they spent is equal to BalanceDelta.amount0()

        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));

        // Mint the achievement
        _mintAchievement(ethSpendAmount, hookData);

        return (this.afterSwap.selector, 0);
    }

    event Debug(uint256 a, uint256 b);

    function _mintAchievement(uint256 ethSpendAmount, bytes calldata hookData) internal {
        // If no hookData is passed in, no achievements will be assigned to anyone
        if (hookData.length == 0) return;

        // Extract user address from hookData
        address user = abi.decode(hookData, (address));

        // If there is hookData but not in the format we're expecting and user address is zero
        // nobody gets any achievements
        if (user == address(0)) return;

        Achievements storage achievements = swapVolume[user];
        achievements.weiVolume += ethSpendAmount;
        uint8 achievementsCounter = achievements.achievementsCounter;
        uint256 wholeEthSpend = achievements.weiVolume / 1e18;

        for (uint8 i = achievementsCounter + 1; i <= wholeEthSpend; i++) {
            emit Debug(i, balanceOf[user][i]);
            if (balanceOf[user][i] == 0) {
                _mint(user, i, 1, "");
                achievementsCounter = i;
            }
        }
        achievements.achievementsCounter = achievementsCounter;
    }
}
