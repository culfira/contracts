// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/BaseWrapper.sol";
import "./interfaces/INonFungiblePositionManager.sol";
import "../interfaces/ICulfiraToken.sol";

/**
 * @title SaucerSwapWrapper
 * @notice Wrapper contract for SaucerSwap liquidity operations
 * @dev Allows Culfira users to provide liquidity to HBAR pairs on SaucerSwap
 */
contract SaucerSwapWrapper is BaseWrapper, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    INonfungiblePositionManager public immutable positionManager;
    ICulfiraToken public immutable culToken;
    address public immutable WHBAR; // Wrapped HBAR address
    
    // Track user positions
    mapping(address => uint256[]) private _userPositions;
    mapping(uint256 => address) private _positionOwner;
    mapping(uint256 => PositionInfo) private _positions;
    
    // Position tracking
    struct PositionInfo {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 createdAt;
        bool isActive;
    }
    
    // --- Events ---
    event LiquidityAdded(
        address indexed user,
        uint256 indexed tokenSN,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    );
    
    event LiquidityRemoved(
        address indexed user,
        uint256 indexed tokenSN,
        uint256 amount0,
        uint256 amount1
    );
    
    event LiquidityIncreased(
        address indexed user,
        uint256 indexed tokenSN,
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    );
    
    event FeesCollected(
        address indexed user,
        uint256 indexed tokenSN,
        uint256 amount0,
        uint256 amount1
    );
    
    event PositionBurned(
        address indexed user,
        uint256 indexed tokenSN
    );
    
    // --- Errors ---
    error NotPositionOwner();
    error InvalidToken();
    error PositionNotEmpty();
    error InvalidTickRange();
    error InsufficientAmount();
    error PositionNotFound();
    error TransferFailed();
    
    // --- Constructor ---
    constructor(
        address _positionManager,
        address _culToken,
        address _whbar
    ) BaseWrapper("SaucerSwap") {
        if (_positionManager == address(0) || _culToken == address(0) || _whbar == address(0)) {
            revert InvalidToken();
        }
        
        positionManager = INonfungiblePositionManager(_positionManager);
        culToken = ICulfiraToken(_culToken);
        WHBAR = _whbar;
    }
    
    // --- Core Liquidity Functions ---
    
    /**
     * @notice Add liquidity to a HBAR/Token pool
     * @param token The ERC20 token to pair with HBAR
     * @param fee The pool fee tier (500, 3000, 10000)
     * @param tickLower The lower tick of the position
     * @param tickUpper The upper tick of the position
     * @param amountHBAR Desired amount of HBAR
     * @param amountToken Desired amount of token
     * @param amountHBARMin Minimum amount of HBAR (slippage protection)
     * @param amountTokenMin Minimum amount of token (slippage protection)
     * @param deadline Transaction deadline
     */
    function addLiquidity(
        address token,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amountHBAR,
        uint256 amountToken,
        uint256 amountHBARMin,
        uint256 amountTokenMin,
        uint256 deadline
    ) external payable nonReentrant returns (
        uint256 tokenSN,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        if (token == address(0) || token == WHBAR) revert InvalidToken();
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (amountHBAR == 0 || amountToken == 0) revert InsufficientAmount();
        if (msg.value < amountHBAR) revert InsufficientAmount();
        
        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountToken);
        
        // Approve position manager
        IERC20(WHBAR).approve(address(positionManager), amountHBAR);
        IERC20(token).approve(address(positionManager), amountToken);
        
        // Determine token order (SaucerSwap uses sorted token addresses)
        (address token0, address token1) = WHBAR < token ? (WHBAR, token) : (token, WHBAR);
        (uint256 amount0Desired, uint256 amount1Desired) = WHBAR < token 
            ? (amountHBAR, amountToken) 
            : (amountToken, amountHBAR);
        (uint256 amount0Min, uint256 amount1Min) = WHBAR < token
            ? (amountHBARMin, amountTokenMin)
            : (amountTokenMin, amountHBARMin);
        
        // Mint position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: address(this),
            deadline: deadline
        });
        
        (tokenSN, liquidity, amount0, amount1) = positionManager.mint{value: msg.value}(params);
        
        // Store position info
        _positions[tokenSN] = PositionInfo({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            createdAt: block.timestamp,
            isActive: true
        });
        
        _userPositions[msg.sender].push(tokenSN);
        _positionOwner[tokenSN] = msg.sender;
        
        // Refund excess tokens
        if (WHBAR < token) {
            if (amount0Desired > amount0) {
                (bool success, ) = msg.sender.call{value: amount0Desired - amount0}("");
                if (!success) revert TransferFailed();
            }
            if (amount1Desired > amount1) {
                IERC20(token).safeTransfer(msg.sender, amount1Desired - amount1);
            }
        } else {
            if (amount1Desired > amount1) {
                (bool success, ) = msg.sender.call{value: amount1Desired - amount1}("");
                if (!success) revert TransferFailed();
            }
            if (amount0Desired > amount0) {
                IERC20(token).safeTransfer(msg.sender, amount0Desired - amount0);
            }
        }
        
        emit LiquidityAdded(msg.sender, tokenSN, amount0, amount1, liquidity);
    }
    
    /**
     * @notice Increase liquidity in an existing position
     * @param tokenSN The serial number of the position NFT
     * @param amountHBAR Additional HBAR amount
     * @param amountToken Additional token amount
     * @param amountHBARMin Minimum HBAR (slippage protection)
     * @param amountTokenMin Minimum token (slippage protection)
     * @param deadline Transaction deadline
     */
    function increaseLiquidity(
        uint256 tokenSN,
        uint256 amountHBAR,
        uint256 amountToken,
        uint256 amountHBARMin,
        uint256 amountTokenMin,
        uint256 deadline
    ) external payable nonReentrant returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        if (_positionOwner[tokenSN] != msg.sender) revert NotPositionOwner();
        PositionInfo storage pos = _positions[tokenSN];
        if (!pos.isActive) revert PositionNotFound();
        if (msg.value < amountHBAR) revert InsufficientAmount();

        address token = pos.token0 == WHBAR ? pos.token1 : pos.token0;

        // Transfer tokens from user and approve
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountToken);
        IERC20(WHBAR).approve(address(positionManager), amountHBAR);
        IERC20(token).approve(address(positionManager), amountToken);

        // Build params inline to reduce stack usage
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenSN: tokenSN,
                amount0Desired: pos.token0 == WHBAR ? amountHBAR : amountToken,
                amount1Desired: pos.token0 == WHBAR ? amountToken : amountHBAR,
                amount0Min: pos.token0 == WHBAR ? amountHBARMin : amountTokenMin,
                amount1Min: pos.token0 == WHBAR ? amountTokenMin : amountHBARMin,
                deadline: deadline
            });

        (liquidity, amount0, amount1) = positionManager.increaseLiquidity{value: msg.value}(params);

        // Update stored liquidity
        pos.liquidity += liquidity;

        // Refund any excess amounts with minimal locals
        uint256 refundedHBAR = 0;
        uint256 refundedToken = 0;
        if (pos.token0 == WHBAR) {
            // amountHBAR -> amount0, amountToken -> amount1
            if (amountHBAR > amount0) refundedHBAR = amountHBAR - amount0;
            if (amountToken > amount1) refundedToken = amountToken - amount1;
        } else {
            // amountHBAR -> amount1, amountToken -> amount0
            if (amountHBAR > amount1) refundedHBAR = amountHBAR - amount1;
            if (amountToken > amount0) refundedToken = amountToken - amount0;
        }

        if (refundedToken > 0) {
            IERC20(token).safeTransfer(msg.sender, refundedToken);
        }
        if (refundedHBAR > 0) {
            (bool sent, ) = msg.sender.call{value: refundedHBAR}("");
            if (!sent) revert TransferFailed();
        }

        emit LiquidityIncreased(msg.sender, tokenSN, amount0, amount1, liquidity);
    }
    
    /**
     * @notice Remove liquidity from a position
     * @param tokenSN The serial number of the position NFT
     * @param liquidity Amount of liquidity to remove
     * @param amount0Min Minimum token0 amount
     * @param amount1Min Minimum token1 amount
     * @param deadline Transaction deadline
     */
    function removeLiquidity(
        uint256 tokenSN,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (_positionOwner[tokenSN] != msg.sender) revert NotPositionOwner();
        if (!_positions[tokenSN].isActive) revert PositionNotFound();
        
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenSN: tokenSN,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            });
        
        (amount0, amount1) = positionManager.decreaseLiquidity(params);
        
        // Update stored liquidity
        _positions[tokenSN].liquidity -= liquidity;
        
        // Collect the removed liquidity
        (uint256 collected0, uint256 collected1) = _collectPosition(tokenSN, msg.sender);
        
        emit LiquidityRemoved(msg.sender, tokenSN, collected0, collected1);
    }
    
    /**
     * @notice Collect fees from a position
     * @param tokenSN The serial number of the position NFT
     */
    function collectFees(uint256 tokenSN) external nonReentrant returns (
        uint256 amount0,
        uint256 amount1
    ) {
        if (_positionOwner[tokenSN] != msg.sender) revert NotPositionOwner();
        
        (amount0, amount1) = _collectPosition(tokenSN, msg.sender);
        
        emit FeesCollected(msg.sender, tokenSN, amount0, amount1);
    }
    
    /**
     * @notice Burn a position NFT (must have 0 liquidity)
     * @param tokenSN The serial number of the position NFT
     */
    function burnPosition(uint256 tokenSN) external nonReentrant {
        if (_positionOwner[tokenSN] != msg.sender) revert NotPositionOwner();
        if (_positions[tokenSN].liquidity > 0) revert PositionNotEmpty();
        
        positionManager.burn(tokenSN);
        
        _positions[tokenSN].isActive = false;
        delete _positionOwner[tokenSN];
        
        emit PositionBurned(msg.sender, tokenSN);
    }
    
    // --- Internal Functions ---
    
    function _collectPosition(
        uint256 tokenSN,
        address recipient
    ) internal returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams memory params =
            INonfungiblePositionManager.CollectParams({
                tokenSN: tokenSN,
                recipient: recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        
        (amount0, amount1) = positionManager.collect(params);
    }
    
    // --- View Functions ---
    
    /**
     * @notice Get all positions for a user
     */
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return _userPositions[user];
    }
    
    /**
     * @notice Get position info
     */
    function getPositionInfo(uint256 tokenSN) external view returns (PositionInfo memory) {
        return _positions[tokenSN];
    }
    
    /**
     * @notice Get position details from SaucerSwap
     */
    function getPositionDetails(uint256 tokenSN) external view returns (
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
    ) {
        return positionManager.positions(tokenSN);
    }
    
    /**
     * @notice Check if user owns a position
     */
    function isPositionOwner(uint256 tokenSN, address user) external view returns (bool) {
        return _positionOwner[tokenSN] == user;
    }
    
    /**
     * @notice Get total number of positions for a user
     */
    function getUserPositionCount(address user) external view returns (uint256) {
        return _userPositions[user].length;
    }
    
    // --- Receive HBAR ---
    receive() external payable {}
}