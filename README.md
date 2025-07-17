# EIP-7702 Portfolio Rebalancer

A test implementation of an automated portfolio rebalancing system using EIP-7702 delegation. This project demonstrates how EOA (Externally Owned Accounts) can delegate portfolio management to smart contracts while maintaining full control over their assets.

## Overview

This is a **test-only implementation** for demonstrating EIP-7702 functionality. The system allows:

- **EOA delegation**: Users can delegate portfolio rebalancing to AI agents
- **Automated rebalancing**: AI agents can automatically rebalance portfolios when they become imbalanced
- **Price-based trading**: Uses mock oracle prices for realistic token exchange rates
- **Safety controls**: Limits on maximum trade amounts and rebalancing thresholds

## Architecture

### Core Components

- **`PortfolioRebalancer.sol`**: Main contract that manages portfolio rebalancing logic
- **`MockOracle.sol`**: Mock price oracle providing USD prices for tokens
- **`MockUniswapRouter.sol`**: Mock Uniswap router for token swapping using oracle prices
- **`TestToken.sol`**: ERC20 test tokens for demonstration

### Key Features

- **EIP-7702 Integration**: Uses delegation for secure EOA-to-contract interactions
- **Signature-based Initialization**: Secure contract initialization with EIP-712 signatures
- **Configurable Parameters**: Adjustable rebalancing thresholds and trade limits
- **Realistic Price Simulation**: Oracle-based exchange rates with fees

## Setup and Installation

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd ai_rebalancing
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

## Running Tests

### Run All Tests
```bash
forge test
```

### Run with Verbose Output
```bash
forge test -vv
```



## Test Scenarios

The test suite covers:

1. **Initial Balanced State**: Verifies portfolio is balanced at startup
2. **Small Imbalance**: Tests that small deviations don't trigger rebalancing
3. **Large Imbalance**: Tests that significant deviations trigger rebalancing
4. **Rebalancing Execution**: Tests actual token swapping and rebalancing
5. **EIP-7702 Delegation**: Tests delegation functionality

### Example Test Flow

1. **Setup**: Deploy tokens, oracle, router, and portfolio rebalancer
2. **Initial State**: Portfolio starts balanced (50% DAI, 30% ETH, 20% BTC)
3. **Create Imbalance**: Add extra DAI to create imbalance
4. **Detect Imbalance**: System detects deviation exceeds 5% threshold
5. **Execute Rebalancing**: AI agent swaps excess DAI for other tokens
6. **Verify Balance**: Portfolio returns to target allocation

## Configuration

### Portfolio Parameters

- **Target Allocations**: 50% DAI, 30% ETH, 20% BTC
- **Rebalance Threshold**: 5% deviation triggers rebalancing
- **Max Trade Amount**: 1% of token balance per trade
- **Oracle Prices**: DAI=$1, ETH=$1, BTC=$2000

### Token Balances

- **Initial DAI**: 5000 DAI
- **Initial ETH**: 3000 ETH  
- **Initial BTC**: 1 BTC

## Security Features

- **Signature Verification**: All initialization requires valid EIP-712 signatures
- **Access Control**: Only AI agents can execute rebalancing
- **Trade Limits**: Maximum trade amounts prevent large position changes
- **Owner Controls**: Contract owner can update critical parameters

## Important Notes

**This is a test implementation only** - not for production use.

- Uses mock contracts for oracle and DEX functionality
- Simplified price calculations and fee structures
- No real market data or liquidity
- Designed for EIP-7702 testing and demonstration

## EIP-7702 Integration

This project demonstrates EIP-7702 delegation patterns:

1. **EOA Delegation**: User delegates portfolio management to contract
2. **Secure Execution**: AI agent can execute trades on behalf of user
3. **Maintained Control**: User retains full control and can revoke delegation
4. **Transparent Operations**: All actions are visible on-chain
