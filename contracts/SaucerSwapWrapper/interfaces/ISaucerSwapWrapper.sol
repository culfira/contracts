// contracts/protocols/saucerswap/interfaces/ISaucerSwapWrapper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ISaucerSwapWrapper - Wrapper interface for SaucerSwap V2 liquidity operations
/// @notice Wraps SaucerSwap's INonfungiblePositionManager to work with wrapper tokens
interface ISaucerSwapWrapper {
    
    // ============ Structs ============
    
    struct MintParams {
        address token0;           // Underlying token0 address
        address token1;           // Underlying token1 address
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    
    struct IncreaseLiquidityParams {
        uint256 tokenSN;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    
    struct DecreaseLiquidityParams {
        uint256 tokenSN;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    
    struct CollectParams {
        uint256 tokenSN;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    
    // ============ Events ============
    
    event LiquidityAdded(
        address indexed user,
        uint256 indexed tokenSN,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    );
    
    event LiquidityIncreased(
        address indexed user,
        uint256 indexed tokenSN,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    );
    
    event LiquidityDecreased(
        address indexed user,
        uint256 indexed tokenSN,
        uint256 amount0,
        uint256 amount1
    );
    
    event FeesCollected(
        address indexed user,
        uint256 indexed tokenSN,
        address recipient,
        uint256 amount0,
        uint256 amount1
    );
    
    event PositionBurned(
        address indexed user,
        uint256 indexed tokenSN
    );
    
    // ============ Errors ============
    
    error InvalidWrapper();
    error WrapperNotRegistered();
    error UnderlyingMismatch();
    error InvalidAmount();
    error SlippageExceeded();
    
    // ============ Functions ============
    
    /// @notice Mint new liquidity position using wrapper tokens
    /// @param params Mint parameters with underlying token addresses
    /// @return tokenSN The token serial number of the new position
    /// @return liquidity The amount of liquidity minted
    /// @return amount0 The amount of token0 used
    /// @return amount1 The amount of token1 used
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenSN,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
    
    /// @notice Increase liquidity in existing position using wrapper tokens
    /// @param params Increase liquidity parameters
    /// @return liquidity The new liquidity amount
    /// @return amount0 The amount of token0 added
    /// @return amount1 The amount of token1 added
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
    
    /// @notice Decrease liquidity from position
    /// @param params Decrease liquidity parameters
    /// @return amount0 The amount of token0 removed
    /// @return amount1 The amount of token1 removed
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);
    
    /// @notice Collect fees from position
    /// @param params Collect parameters
    /// @return amount0 The amount of token0 collected
    /// @return amount1 The amount of token1 collected
    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);
    
    /// @notice Burn position NFT
    /// @param tokenSN The token serial number to burn
    function burn(uint256 tokenSN) external payable;
    
    /// @notice Get position information
    /// @param tokenSN The token serial number
    /// @return token0 Underlying token0 address
    /// @return token1 Underlying token1 address
    /// @return fee Pool fee
    /// @return tickLower Lower tick
    /// @return tickUpper Upper tick
    /// @return liquidity Position liquidity
    /// @return feeGrowthInside0LastX128 Fee growth token0
    /// @return feeGrowthInside1LastX128 Fee growth token1
    /// @return tokensOwed0 Tokens owed token0
    /// @return tokensOwed1 Tokens owed token1
    function positions(uint256 tokenSN)
        external
        view
        returns (
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}