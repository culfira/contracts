# Culfira Multi-Asset Vault Protocol

## Abstract

Culfira is a decentralized stokvel protocol built on Hedera that enables community-based asset pooling and yield farming through multi-asset weighted pools. The protocol uses wrapper tokens to prevent rug pulls while allowing sophisticated DeFi yield strategies, combining traditional stokvel mechanics with modern DeFi primitives.

## Core Architecture

### Wrapper Token System

The protocol operates on a foundation of ERC20 wrapper tokens that encapsulate underlying assets:

- **Asset Wrapping**: Users deposit underlying tokens (HBAR, USDC, ETH) to receive wrapper tokens (xHBAR, xUSDC, xETH)
- **Rug Pull Prevention**: Wrapper tokens implement transfer restrictions when locked in vaults
- **Yield Farming Gateway**: Locked tokens can be transferred for yield farming but cannot be unwrapped to underlying assets
- **Protocol Registry**: Centralized authorization system for DeFi protocols to interact with wrapper tokens

### Multi-Asset Vault Architecture

Each vault operates as an autonomous stokvel community with the following properties:

- **Member Management**: Users join vaults by depositing multiple wrapper tokens with specified weights
- **Round-Based Distribution**: Sequential rounds where one member becomes the "winner" and receives all pool assets
- **Multi-Asset Pools**: Pools contain multiple wrapper tokens with Balancer-style weighted compositions
- **Decentralized Operations**: Members can initiate rounds and complete them without centralized control

### Weighted Pool Mathematics

The protocol implements Balancer-inspired weighted pool mechanics:

- **Weight Validation**: Asset weights must sum to 100% (10,000 basis points)
- **Pool Composition**: Each pool maintains target ratios between different wrapper tokens
- **Health Factor Calculation**: Continuous monitoring of pool composition deviations
- **Rebalancing Incentives**: Penalties for maintaining unhealthy pool ratios

## Health Factor & Risk Management

### Health Factor Definition

The health factor represents the minimum deviation ratio of any asset in the pool:

```
Health Factor = min(current_balance_i / initial_balance_i * weight_i) for all assets i
```

### Penalty Mechanism

- **Threshold**: Health factor must remain ≥ 95%
- **Violation Response**: Assets falling below threshold trigger penalty calculations
- **Insurance Pool**: Penalty amounts are transferred to insurance pools for distribution
- **Score Reduction**: Member scores decrease proportionally to health factor violations

### Insurance Distribution

- **Accumulation**: Penalties accumulate in insurance pools throughout vault cycles
- **Distribution**: At cycle end, insurance pools distribute proportionally to member scores
- **Incentive Alignment**: Higher scores (better health factor maintenance) receive larger insurance shares

## Protocol Integration Framework

### Authorization Layers

1. **Manual Vault Authorization**: Direct owner-controlled vault permissions
2. **Protocol Registry**: Centralized registry of approved DeFi protocols
3. **Auto-Authorization**: Automatic permission granting for registered protocols

### DeFi Protocol Categories

- **DEX**: Decentralized exchanges (SaucerSwap, Uniswap-style)
- **Lending**: Lending protocols (Compound, Aave-style)
- **Staking**: Native and liquid staking protocols
- **Yield Farming**: Specialized yield farming protocols
- **Liquidity Mining**: Liquidity provision incentive programs

### Wrapper Token Constraints

Winner users receiving pool assets can:

- Transfer wrapper tokens to authorized protocols for yield farming
- Participate in liquidity pools and lending markets
- Stake in various protocols

Winner users cannot:

- Unwrap tokens to underlying assets (preventing rug pulls)
- Transfer beyond free balance limits
- Withdraw from vault obligations

## Round Lifecycle

1. **Initialization**: Vault created with custom cycle duration (1-365 days)
2. **Member Onboarding**: Users deposit multi-asset wrapper tokens with weights
3. **Round Activation**: Any active member can initiate new rounds
4. **Asset Distribution**: Winner claims all pool assets to their wallet (locked state)
5. **Yield Farming Period**: Winner deploys assets across approved DeFi protocols
6. **Health Monitoring**: Continuous health factor tracking and penalty calculation
7. **Round Completion**: Winner or members complete round after cycle duration
8. **Asset Recovery**: All assets returned to vault for next round
9. **Insurance Distribution**: Accumulated penalties distributed based on member scores

## Security Model

- **Immutable Locks**: Wrapper tokens cannot be unwrapped when locked in vaults
- **Health Factor Enforcement**: Automatic penalty system for pool composition violations
- **Protocol Whitelisting**: Only approved protocols can interact with locked tokens
- **Decentralized Governance**: Members control round timing and operations
- **Emergency Safeguards**: Owner oversight for critical vault operations

## Economic Incentives

### Member Scoring System

- **Base Score**: 100% (10,000 basis points) for healthy pool maintenance
- **Penalty Reduction**: Score decreases proportional to health factor violations
- **Insurance Rewards**: Higher scores receive larger insurance pool distributions

### Yield Optimization

- **Capital Efficiency**: Winners deploy entire pool capital for maximum yield
- **Risk Diversification**: Multi-asset pools spread risk across different tokens
- **Protocol Flexibility**: Integration with multiple DeFi protocols for yield strategies
- **Penalty Mitigation**: Insurance pools compensate for individual poor performance

This protocol design creates a sustainable, community-driven investment vehicle that combines the social aspects of traditional stokvels with the capital efficiency and yield opportunities of modern DeFi, while maintaining strong safeguards against malicious behavior.
