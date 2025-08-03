# AchievementsHook

A Uniswap v4 hook that assigns achievements to users based on their ETH swap volume.

## Overview

AchievementsHook tracks cumulative ETH input volume for swaps from ETH to any token and mints ERC1155 achievement tokens representing volume milestones reached by each user.

## Features

- **Volume Tracking**: Monitors ETH input amounts for ETH � Token swaps only
- **Achievement Minting**: Issues ERC1155 tokens for each whole ETH volume milestone reached
- **Cumulative Rewards**: Tracks lifetime volume across all swaps for each user
- **Anti-Double Minting**: Prevents duplicate achievements for the same milestone

## How It Works

1. Users perform swaps from ETH to tokens with user address encoded in `hookData`
2. Hook tracks cumulative ETH volume spent by each user
3. For each whole ETH milestone reached (1 ETH, 2 ETH, 3 ETH, etc.), an achievement token is minted
4. Achievement tokens are ERC1155 NFTs with token ID corresponding to the ETH volume milestone

## Usage

Deploy the hook with appropriate hook permissions (`AFTER_SWAP_FLAG`) and include the user address in the swap's `hookData` parameter:

```solidity
bytes memory hookData = abi.encode(userAddress);
```

Only ETH � Token swaps (`zeroForOne = true`) in pools where ETH is currency0 will trigger achievement minting.

## Contract Files

- `src/AchievementsHook.sol` - Main hook contract
- `test/AchievementsHook.t.sol` - Test suite