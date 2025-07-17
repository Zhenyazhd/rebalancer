// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

/**
 * @title MockUniswapRouter
 * @dev Simple mock Uniswap V2 router for testing EIP-7702 rebalancing functionality
 * Implements IUniswapV2Router interface with basic token swapping using oracle prices
 */
contract MockUniswapRouter is Ownable {
    // Events for tracking swaps
    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    // Fee percentage (0.3% like Uniswap V2)
    uint256 public constant FEE_BPS = 30; // 0.3% = 30 basis points

    // Price oracle for getting token prices
    IPriceOracle public oracle;

    /**
     * @dev Constructor
     * @param initialOwner Address of the contract owner
     * @param _oracle Address of the price oracle
     */
    constructor(address initialOwner, address _oracle) Ownable(initialOwner) {
        oracle = IPriceOracle(_oracle);
    }

    /**
     * @dev Set oracle address (only owner)
     * @param _oracle New oracle address
     */
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "MockUniswap: invalid oracle address");
        oracle = IPriceOracle(_oracle);
    }

    /**
     * @dev Calculate exchange rate between two tokens using oracle prices
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input tokens
     * @return amountOut Amount of output tokens
     */
    function calculateAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        // Get prices from oracle (in USD with 18 decimals)
        uint256 priceIn = oracle.getPrice(tokenIn);
        uint256 priceOut = oracle.getPrice(tokenOut);

        require(priceIn > 0, "MockUniswap: invalid input token price");
        require(priceOut > 0, "MockUniswap: invalid output token price");

        uint256 usdValue = (amountIn * priceIn) / 1e18;
        amountOut = (usdValue * 1e18) / priceOut;

        uint256 fee = (amountOut * FEE_BPS) / 10000;
        amountOut = amountOut - fee;
    }

    /**
     * @dev Swap exact tokens for tokens
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of output tokens
     * @param path Array of token addresses (only first and last are used)
     * @param to Recipient of output tokens
     * @param deadline Deadline for the swap (ignored for simplicity)
     * @return amounts Array with input and output amounts
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "MockUniswap: invalid path");
        require(to != address(0), "MockUniswap: invalid recipient");
        require(amountIn > 0, "MockUniswap: zero input amount");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        uint256 amountOut = calculateAmountOut(tokenIn, tokenOut, amountIn);
        require(
            amountOut >= amountOutMin,
            "MockUniswap: insufficient output amount"
        );

        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "MockUniswap: transfer from failed"
        );

        require(
            IERC20(tokenOut).transfer(to, amountOut),
            "MockUniswap: transfer to failed"
        );

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountOut;

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, to);
    }

    /**
     * @dev Emergency function to withdraw any stuck tokens (only owner)
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        require(to != address(0), "MockUniswap: invalid recipient");
        require(
            IERC20(token).transfer(to, amount),
            "MockUniswap: emergency withdraw failed"
        );
    }

    /**
     * @dev Get expected output amount for a swap
     * @param amountIn Amount of input tokens
     * @param path Array of token addresses
     * @return amounts Array with input and output amounts
     */
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "MockUniswap: invalid path");
        require(amountIn > 0, "MockUniswap: zero input amount");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        uint256 amountOut = calculateAmountOut(tokenIn, tokenOut, amountIn);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountOut;

        return amounts;
    }

    /**
     * @dev Get required input amount for desired output
     * @param amountOut Desired output amount
     * @param path Array of token addresses
     * @return amounts Array with required input and desired output amounts
     */
    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "MockUniswap: invalid path");
        require(amountOut > 0, "MockUniswap: zero output amount");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        uint256 priceIn = oracle.getPrice(tokenIn);
        uint256 priceOut = oracle.getPrice(tokenOut);

        require(priceIn > 0, "MockUniswap: invalid input token price");
        require(priceOut > 0, "MockUniswap: invalid output token price");

        uint256 usdValue = (amountOut * priceOut) / 1e18;

        uint256 amountInBeforeFee = (usdValue * 1e18) / priceIn;
        uint256 amountIn = (amountInBeforeFee * 10000) / (10000 - FEE_BPS);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountOut;

        return amounts;
    }

    /**
     * @dev Get current exchange rate between two tokens
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return rate Exchange rate (amount of tokenOut per 1 tokenIn, with 18 decimals)
     */
    function getExchangeRate(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 rate) {
        uint256 priceIn = oracle.getPrice(tokenIn);
        uint256 priceOut = oracle.getPrice(tokenOut);

        require(priceIn > 0, "MockUniswap: invalid input token price");
        require(priceOut > 0, "MockUniswap: invalid output token price");

        rate = (priceIn * 1e18) / priceOut;
        rate = (rate * (10000 - FEE_BPS)) / 10000;
    }
}
