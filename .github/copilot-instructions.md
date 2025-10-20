# Culfira Multi-Asset Vault Protocol

## Architecture Overview

This is a DeFi stokvel protocol built on Hedera managing multi-asset pools through Balancer-inspired weighted pooling mechanisms.

### Core Components

- **MultiAssetVault.sol**: Main vault contract managing rounds, members, and multi-asset pools
- **WrapperToken.sol**: ERC20Wrapper-based tokens that lock underlying assets preventing rug pulls  
- **WeightedPoolLib.sol**: Library implementing Balancer-style weighted pool mathematics
- **VaultFactory.sol**: Factory for creating new vault instances
- **InsuranceManager.sol**: Manages penalty distribution and insurance pools

### Key Business Logic

**Round-based Winner Distribution**: Each round selects a winner who receives ALL pool assets to their wallet for yield farming. Assets remain locked in wrappers - winners can transfer for farming but cannot withdraw to underlying tokens.

**Health Factor Enforcement**: Winners must maintain asset ratios during their round. Health factor calculated using WeightedPoolLib comparing initial vs current balances. Violations below 95% trigger penalties.

**Wrapper Token Constraints**: Built on OpenZeppelin's ERC20Wrapper. Users can transfer wrapper tokens freely (for yield farming) but can only withdraw to underlying tokens for unlocked balances. Vault-locked tokens cannot be unwrapped.

## Development Patterns

### Asset Management Flow
```solidity
// Deposit underlying tokens (ERC20Wrapper pattern)
IERC20(underlying).approve(wrapper, amount);
wrapper.depositFor(user, amount); // or wrapper.wrap(amount) for legacy

### Asset Management Flow
```solidity
// Deposit underlying tokens (ERC20Wrapper pattern)
IERC20(underlying).approve(wrapper, amount);
wrapper.depositFor(user, amount); // or wrapper.wrap(amount) for legacy

// Join vault with multi-asset weighted deposit
joinVault(address[] wrappers, uint256[] amounts, uint256[] weights)

// Winner claims all pool assets to wallet
claimWinnerAssets() // Transfers assets to winner's wallet

// Owner completes round with health factor check
completeRound() // Winner returns assets, penalties applied if needed

// Withdraw only unlocked tokens
wrapper.withdrawTo(account, amount); // or wrapper.unwrap(amount) for legacy
```

// Winner claims all pool assets to wallet
claimWinnerAssets() // Transfers assets to winner's wallet

// Owner completes round with health factor check
completeRound() // Winner returns assets, penalties applied if needed

// Withdraw only unlocked tokens
wrapper.withdrawTo(account, amount); // or wrapper.unwrap(amount) for legacy
```

### Weight Validation
Always use `WeightedPoolLib.validateWeights()` - converts from vault's `SCORE_PRECISION` (10000) to lib's `PRECISION` (1e18):
```solidity
uint256[] memory libWeights = new uint256[](weights.length);
for (uint256 i = 0; i < weights.length; i++) {
    libWeights[i] = (weights[i] * WeightedPoolLib.PRECISION) / SCORE_PRECISION;
}
require(WeightedPoolLib.validateWeights(libWeights));
```

### Health Factor Pattern
Health factors check winner's wallet balances, not vault balances, since assets transfer to winner during rounds:
```solidity
currentBalances[i] = WrapperToken(asset.wrapperToken).balanceOf(winner);
uint256 healthFactor = WeightedPoolLib.calculateHealthFactor(initialBalances, currentBalances, weights);
```

## Critical Workflows

**Member Lifecycle**: Deposit → Lock in wrappers → Join vault → Win round → Claim assets → Yield farm → Return assets → Health check → Score update

**Round Completion**: Winner must return assets to vault before `completeRound()` for proper health factor calculation and penalty distribution

## Integration Points

- **WrapperToken**: Use existing `lockTokens`/`unlockTokens` interface - no custom yield farming permissions needed
- **WeightedPoolLib**: Handles all pool math - use for weight validation and health factor calculation  
- **Hardhat + Viem**: Tests use viem clients with Hardhat Ignition deployment modules

## Testing Setup

Deploy contracts using Ignition modules:
```typescript
const { viem, ignition } = await network.connect();
const contracts = await deployCulfiraWithIgnition(viem, ignition);
```

Run with: `npx hardhat test`