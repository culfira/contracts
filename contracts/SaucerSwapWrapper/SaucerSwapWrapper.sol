// contracts/protocols/saucerswap/SaucerSwapWrapper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../WrapperRegistry.sol";
import "../WrapperToken.sol";
import "./interfaces/ISaucerSwapWrapper.sol";
import "./interfaces/INonfungiblePositionManager.sol";

/// @title SaucerSwapWrapper - Wrapper for SaucerSwap V2 liquidity operations
/// @notice Enables liquidity provision using Culfira wrapper tokens
contract SaucerSwapWrapper is ISaucerSwapWrapper, Ownable, ReentrancyGuard {
    
    // ============ State Variables ============
    
    /// @notice SaucerSwap V2 NonfungiblePositionManager address
    address public immutable positionManager;
    
    /// @notice Culfira WrapperRegistry
    WrapperRegistry public immutable wrapperRegistry;
    
    /// @dev Mapping from tokenSN to original owner
    mapping(uint256 => address) public positionOwners;
    
    // ============ Constructor ============
    
    constructor(
        address positionManager_,
        address wrapperRegistry_
    ) Ownable(msg.sender) {
        require(positionManager_ != address(0), "Invalid position manager");
        require(wrapperRegistry_ != address(0), "Invalid wrapper registry");
        
        positionManager = positionManager_;
        wrapperRegistry = WrapperRegistry(wrapperRegistry_);
    }
    
    // ============ External Functions ============
    
    /// @inheritdoc ISaucerSwapWrapper
    function mint(MintParams calldata params)
        external
        payable
        override
        nonReentrant
        returns (
            uint256 tokenSN,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // Get wrapper tokens for underlying tokens
        address wrapper0 = wrapperRegistry.underlyingToWrapper(params.token0);
        address wrapper1 = wrapperRegistry.underlyingToWrapper(params.token1);
        
        if (wrapper0 == address(0) || wrapper1 == address(0)) {
            revert WrapperNotRegistered();
        }
        
        // Transfer wrapper tokens from user
        WrapperToken(wrapper0).transferFrom(
            msg.sender,
            address(this),
            params.amount0Desired
        );
        WrapperToken(wrapper1).transferFrom(
            msg.sender,
            address(this),
            params.amount1Desired
        );
        
        // Unwrap to underlying tokens
        WrapperToken(wrapper0).withdrawTo(address(this), params.amount0Desired);
        WrapperToken(wrapper1).withdrawTo(address(this), params.amount1Desired);
        
        // Approve position manager
        IERC20(params.token0).approve(positionManager, params.amount0Desired);
        IERC20(params.token1).approve(positionManager, params.amount1Desired);
        
        // Call SaucerSwap position manager mint
        (tokenSN, liquidity, amount0, amount1) = INonfungiblePositionManager(positionManager).mint(
            INonfungiblePositionManager.MintParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: address(this),
                deadline: params.deadline
            })
        );
        
        // Store position owner
        positionOwners[tokenSN] = msg.sender;
        
        // Wrap and return unused tokens
        uint256 unused0 = params.amount0Desired - amount0;
        uint256 unused1 = params.amount1Desired - amount1;
        
        if (unused0 > 0) {
            IERC20(params.token0).approve(wrapper0, unused0);
            WrapperToken(wrapper0).depositFor(msg.sender, unused0);
        }
        
        if (unused1 > 0) {
            IERC20(params.token1).approve(wrapper1, unused1);
            WrapperToken(wrapper1).depositFor(msg.sender, unused1);
        }
        
        emit LiquidityAdded(
            msg.sender,
            tokenSN,
            params.token0,
            params.token1,
            amount0,
            amount1,
            liquidity
        );
    }
    
    /// @inheritdoc ISaucerSwapWrapper
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        override
        nonReentrant
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        if (positionOwners[params.tokenSN] != msg.sender) {
            revert InvalidAmount();
        }
        
        // Get position info to determine tokens
        (
            address token0,
            address token1,
            ,,,,,,,
        ) = INonfungiblePositionManager(positionManager).positions(params.tokenSN);
        
        // Get wrapper tokens
        address wrapper0 = wrapperRegistry.underlyingToWrapper(token0);
        address wrapper1 = wrapperRegistry.underlyingToWrapper(token1);
        
        if (wrapper0 == address(0) || wrapper1 == address(0)) {
            revert WrapperNotRegistered();
        }
        
        // Transfer wrapper tokens from user
        WrapperToken(wrapper0).transferFrom(
            msg.sender,
            address(this),
            params.amount0Desired
        );
        WrapperToken(wrapper1).transferFrom(
            msg.sender,
            address(this),
            params.amount1Desired
        );
        
        // Unwrap to underlying tokens
        WrapperToken(wrapper0).withdrawTo(address(this), params.amount0Desired);
        WrapperToken(wrapper1).withdrawTo(address(this), params.amount1Desired);
        
        // Approve position manager
        IERC20(token0).approve(positionManager, params.amount0Desired);
        IERC20(token1).approve(positionManager, params.amount1Desired);
        
        // Call SaucerSwap increase liquidity
        (liquidity, amount0, amount1) = INonfungiblePositionManager(positionManager).increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenSN: params.tokenSN,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            })
        );
        
        // Wrap and return unused tokens
        uint256 unused0 = params.amount0Desired - amount0;
        uint256 unused1 = params.amount1Desired - amount1;
        
        if (unused0 > 0) {
            IERC20(token0).approve(wrapper0, unused0);
            WrapperToken(wrapper0).depositFor(msg.sender, unused0);
        }
        
        if (unused1 > 0) {
            IERC20(token1).approve(wrapper1, unused1);
            WrapperToken(wrapper1).depositFor(msg.sender, unused1);
        }
        
        emit LiquidityIncreased(
            msg.sender,
            params.tokenSN,
            amount0,
            amount1,
            liquidity
        );
    }
    
    /// @inheritdoc ISaucerSwapWrapper
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (positionOwners[params.tokenSN] != msg.sender) {
            revert InvalidAmount();
        }
        
        // Get position info to determine tokens
        (
            address token0,
            address token1,
            ,,,,,,,
        ) = INonfungiblePositionManager(positionManager).positions(params.tokenSN);
        
        // Get wrapper tokens
        address wrapper0 = wrapperRegistry.underlyingToWrapper(token0);
        address wrapper1 = wrapperRegistry.underlyingToWrapper(token1);
        
        if (wrapper0 == address(0) || wrapper1 == address(0)) {
            revert WrapperNotRegistered();
        }
        
        // Call SaucerSwap decrease liquidity
        (amount0, amount1) = INonfungiblePositionManager(positionManager).decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenSN: params.tokenSN,
                liquidity: params.liquidity,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            })
        );
        
        emit LiquidityDecreased(
            msg.sender,
            params.tokenSN,
            amount0,
            amount1
        );
    }
    
    /// @inheritdoc ISaucerSwapWrapper
    function collect(CollectParams calldata params)
        external
        payable
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (positionOwners[params.tokenSN] != msg.sender) {
            revert InvalidAmount();
        }
        
        // Get position info to determine tokens
        (
            address token0,
            address token1,
            ,,,,,,,
        ) = INonfungiblePositionManager(positionManager).positions(params.tokenSN);
        
        // Get wrapper tokens
        address wrapper0 = wrapperRegistry.underlyingToWrapper(token0);
        address wrapper1 = wrapperRegistry.underlyingToWrapper(token1);
        
        if (wrapper0 == address(0) || wrapper1 == address(0)) {
            revert WrapperNotRegistered();
        }
        
        // Collect to this contract
        (amount0, amount1) = INonfungiblePositionManager(positionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenSN: params.tokenSN,
                recipient: address(this),
                amount0Max: params.amount0Max,
                amount1Max: params.amount1Max
            })
        );
        
        // Wrap collected tokens
        if (amount0 > 0) {
            IERC20(token0).approve(wrapper0, amount0);
            WrapperToken(wrapper0).depositFor(params.recipient, amount0);
        }
        
        if (amount1 > 0) {
            IERC20(token1).approve(wrapper1, amount1);
            WrapperToken(wrapper1).depositFor(params.recipient, amount1);
        }
        
        emit FeesCollected(
            msg.sender,
            params.tokenSN,
            params.recipient,
            amount0,
            amount1
        );
    }
    
    /// @inheritdoc ISaucerSwapWrapper
    function burn(uint256 tokenSN) external payable override nonReentrant {
        if (positionOwners[tokenSN] != msg.sender) {
            revert InvalidAmount();
        }
        
        // Call SaucerSwap burn
        INonfungiblePositionManager(positionManager).burn(tokenSN);
        
        // Clear position owner
        delete positionOwners[tokenSN];
        
        emit PositionBurned(msg.sender, tokenSN);
    }
    
    /// @inheritdoc ISaucerSwapWrapper
    function positions(uint256 tokenSN)
        external
        view
        override
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
        )
    {
        return INonfungiblePositionManager(positionManager).positions(tokenSN);
    }
}