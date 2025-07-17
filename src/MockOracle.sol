// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockOracle is Ownable {
    // Events for tracking price updates
    event PriceUpdated(
        address indexed token,
        uint256 oldPrice,
        uint256 newPrice
    );
    event TokenAdded(address indexed token, uint256 price);
    event TokenRemoved(address indexed token);

    // Mapping from token address to price (in USD with 18 decimals)
    mapping(address => uint256) public prices;

    // Array of supported tokens
    address[] public supportedTokens;

    // Mapping to track if token is supported
    mapping(address => bool) public isSupported;

    // Default price for unsupported tokens (0.01 USD)
    uint256 public defaultPrice = 0.01e18;

    // Price precision (18 decimals)
    uint256 public constant PRICE_PRECISION = 1e18;

    /**
     * @dev Constructor
     * @param initialOwner Address of the contract owner
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Get price for a token in USD (18 decimals)
     * @param token Token address
     * @return price Price in USD with 18 decimals
     */
    function getPrice(address token) external view returns (uint256) {
        if (isSupported[token]) {
            return prices[token];
        }
        return defaultPrice;
    }

    /**
     * @dev Add or update token price (only owner)
     * @param token Token address
     * @param price Price in USD with 18 decimals
     */
    function setPrice(address token, uint256 price) public onlyOwner {
        require(token != address(0), "MockOracle: invalid token address");
        require(price > 0, "MockOracle: price must be greater than 0");

        uint256 oldPrice = prices[token];
        prices[token] = price;

        if (!isSupported[token]) {
            supportedTokens.push(token);
            isSupported[token] = true;
            emit TokenAdded(token, price);
        } else {
            emit PriceUpdated(token, oldPrice, price);
        }
    }

    /**
     * @dev Remove token from supported list (only owner)
     * @param token Token address to remove
     */
    function removeToken(address token) external onlyOwner {
        require(isSupported[token], "MockOracle: token not supported");

        isSupported[token] = false;
        delete prices[token];

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];
                supportedTokens.pop();
                break;
            }
        }

        emit TokenRemoved(token);
    }

    /**
     * @dev Set default price for unsupported tokens (only owner)
     * @param newDefaultPrice New default price in USD with 18 decimals
     */
    function setDefaultPrice(uint256 newDefaultPrice) external onlyOwner {
        require(
            newDefaultPrice > 0,
            "MockOracle: default price must be greater than 0"
        );
        defaultPrice = newDefaultPrice;
    }

    /**
     * @dev Get all supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @dev Get prices for multiple tokens
     * @param tokens Array of token addresses
     * @return tokenPrices Array of prices in USD with 18 decimals
     */
    function getPrices(
        address[] calldata tokens
    ) external view returns (uint256[] memory tokenPrices) {
        tokenPrices = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (isSupported[tokens[i]]) {
                tokenPrices[i] = prices[tokens[i]];
            } else {
                tokenPrices[i] = defaultPrice;
            }
        }
        return tokenPrices;
    }

    /**
     * @dev Check if token is supported
     * @param token Token address
     * @return True if token is supported
     */
    function supportsToken(address token) external view returns (bool) {
        return isSupported[token];
    }

    /**
     * @dev Get number of supported tokens
     * @return Count of supported tokens
     */
    function getSupportedTokenCount() external view returns (uint256) {
        return supportedTokens.length;
    }

    /**
     * @dev Simulate price volatility by updating prices with random-like changes
     * @param tokens Array of token addresses to update
     * @param volatilityBps Volatility in basis points (e.g., 500 = 5%)
     */
    function simulateChanges(
        address[] calldata tokens,
        uint256 volatilityBps
    ) external onlyOwner {
        require(
            volatilityBps <= 1000,
            "MockOracle: volatility too high (max 10%)"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            if (isSupported[tokens[i]]) {
                uint256 currentPrice = prices[tokens[i]];
                uint256 change = (currentPrice * volatilityBps) / 10000;

                // Simulate random up/down movement
                uint256 randomFactor = uint256(
                    keccak256(
                        abi.encodePacked(
                            block.timestamp,
                            block.prevrandao,
                            tokens[i]
                        )
                    )
                ) % 2;

                uint256 newPrice;
                if (randomFactor == 0) {
                    newPrice = currentPrice + change;
                } else {
                    newPrice = currentPrice > change
                        ? currentPrice - change
                        : currentPrice;
                }

                setPrice(tokens[i], newPrice);
            }
        }
    }

    /**
     * @dev Emergency function to reset all prices to default (only owner)
     */
    function emergencyReset() external onlyOwner {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            isSupported[token] = false;
            delete prices[token];
        }
        delete supportedTokens;
    }
}
