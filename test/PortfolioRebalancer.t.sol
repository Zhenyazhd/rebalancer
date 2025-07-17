// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PortfolioRebalancer} from "../src/Rebalancer.sol";
import {TestToken} from "../src/TestToken.sol";
import {MockOracle} from "../src/MockOracle.sol";
import {MockUniswapRouter} from "../src/MockUniswapRouter.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Vm} from "forge-std/Vm.sol";

contract PortfolioRebalancerTest is Test {
    // Test accounts
    uint256 constant PRIVATE_KEY = 0xB0B;
    address BOB = vm.addr(PRIVATE_KEY);
    address constant AI_AGENT = address(0xA11A93);
    address constant ALICE = address(0x1234);
    address constant ORACLE_OWNER = address(0x0A11CE);
    address constant ROUTER_OWNER = address(0x0BEEF);
    Vm.SignedDelegation public signedDelegation;

    // Test tokens
    TestToken public tokenDAI;
    TestToken public tokenETH;
    TestToken public tokenBTC;

    // Contracts
    MockOracle public oracle;
    MockUniswapRouter public router;
    PortfolioRebalancer public portfolioImplementation;

    // Token prices in USD (18 decimals)
    uint256 constant DAI_PRICE = 1e18; // $1.00
    uint256 constant ETH_PRICE = 1e18; // $1.00
    uint256 constant BTC_PRICE = 2000e18; // $2000.00

    // Initial balances
    uint256 constant INITIAL_DAI = 5000e18; // 5000 DAI
    uint256 constant INITIAL_ETH = 3000e18; // 1.5 ETH
    uint256 constant INITIAL_BTC = 1e18; // 0.05 BTC

    function setUp() public {
        // Deploy test tokens
        tokenDAI = new TestToken(BOB, INITIAL_DAI);
        tokenETH = new TestToken(BOB, INITIAL_ETH);
        tokenBTC = new TestToken(BOB, INITIAL_BTC);

        // Deploy oracle and set prices
        oracle = new MockOracle(ORACLE_OWNER);
        vm.startPrank(ORACLE_OWNER);
        oracle.setPrice(address(tokenDAI), DAI_PRICE);
        oracle.setPrice(address(tokenETH), ETH_PRICE);
        oracle.setPrice(address(tokenBTC), BTC_PRICE);
        vm.stopPrank();

        // Deploy router with oracle
        router = new MockUniswapRouter(ROUTER_OWNER, address(oracle));

        // Fund router with tokens for swapping
        vm.startPrank(ROUTER_OWNER);
        tokenDAI.mint(address(router), 10000e18);
        tokenETH.mint(address(router), 10000e18);
        tokenBTC.mint(address(router), 10000e18);
        vm.stopPrank();

        // Deploy portfolio rebalancer
        portfolioImplementation = new PortfolioRebalancer();

        signedDelegation = vm.signDelegation(address(portfolioImplementation), PRIVATE_KEY);
        vm.attachDelegation(signedDelegation);

        // Create portfolio configuration
        PortfolioRebalancer.Asset[] memory assets = new PortfolioRebalancer.Asset[](3);
        assets[0] = PortfolioRebalancer.Asset(address(tokenDAI), 5000); // 50%
        assets[1] = PortfolioRebalancer.Asset(address(tokenETH), 3000); // 30%
        assets[2] = PortfolioRebalancer.Asset(address(tokenBTC), 2000); // 20%

        // Create signature for initialization
        bytes memory signature = createInitializationSignature(
            assets,
            500, // rebalanceThresholdBps = 5%
            100, // maxAmount = 1%
            address(router),
            address(oracle),
            AI_AGENT,
            BOB // owner
        );

        // Initialize portfolio rebalancer
        PortfolioRebalancer(BOB).initialize(
            assets,
            500, // rebalanceThresholdBps = 5%
            100, // maxAmount = 1%
            address(router),
            address(oracle),
            AI_AGENT,
            BOB,
            signature
        );
    }

    function testInitialBalancedState() public {
        console2.log("signedDelegation.implementation", signedDelegation.implementation);
        console2.log("signedDelegation.nonce", signedDelegation.nonce);
        console2.log("signedDelegation.v", signedDelegation.v);
        console2.logBytes32(signedDelegation.r);
        console2.logBytes32(signedDelegation.s);

        assertEq(tokenDAI.balanceOf(BOB), INITIAL_DAI);
        assertEq(tokenETH.balanceOf(BOB), INITIAL_ETH);
        assertEq(tokenBTC.balanceOf(BOB), INITIAL_BTC);

        // Calculate total value
        uint256 totalValue = ((INITIAL_DAI * oracle.getPrice(address(tokenDAI))) / 1e18)
            + ((INITIAL_ETH * oracle.getPrice(address(tokenETH))) / 1e18)
            + ((INITIAL_BTC * oracle.getPrice(address(tokenBTC))) / 1e18);

        console2.log("Total portfolio value: $", totalValue / 1e18);

        bool isDisbalanced = PortfolioRebalancer(BOB).ifDisbalanced();
        assertFalse(isDisbalanced, "Portfolio should be balanced initially");
        console2.log("Portfolio is balanced: ", !isDisbalanced);
    }

    function testImbalance() public {
        // Add 2000 DAI to create imbalance
        vm.prank(BOB);
        tokenDAI.mint(BOB, 2000e18);

        // Check new balance
        assertEq(tokenDAI.balanceOf(BOB), INITIAL_DAI + 2000e18);

        // Calculate new total value
        uint256 newTotalValue = (((INITIAL_DAI + 2000e18) * oracle.getPrice(address(tokenDAI))) / 1e18)
            + ((INITIAL_ETH * oracle.getPrice(address(tokenETH))) / 1e18)
            + ((INITIAL_BTC * oracle.getPrice(address(tokenBTC))) / 1e18);

        console2.log("New total value after +2000 DAI: $", newTotalValue / 1e18);

        // Check if portfolio is now disbalanced (should exceed 5% threshold)
        bool isDisbalanced = PortfolioRebalancer(BOB).ifDisbalanced();
        assertTrue(isDisbalanced, "Large imbalance should exceed threshold");

        console2.log("Portfolio is disbalanced after large imbalance: ", isDisbalanced);
    }

    function testRebalancing() public {
        // First create large imbalance
        vm.prank(BOB);
        tokenDAI.mint(BOB, 2000e18);

        // Verify portfolio is disbalanced
        assertTrue(PortfolioRebalancer(BOB).ifDisbalanced(), "Portfolio should be disbalanced");

        // Get initial balances before rebalancing
        uint256 initialDAI = tokenDAI.balanceOf(BOB);
        uint256 initialETH = tokenETH.balanceOf(BOB);
        uint256 initialBTC = tokenBTC.balanceOf(BOB);

        console2.log("Before rebalancing:");
        console2.log("DAI balance:", initialDAI / 1e18);
        console2.log("ETH balance:", initialETH / 1e18);
        console2.log("BTC balance:", initialBTC / 1e18);

        // AI agent executes rebalancing (swap DAI to ETH)
        address[] memory path = new address[](2);
        path[0] = address(tokenDAI);
        path[1] = address(tokenBTC);

        uint256 amountIn = 50e18; // 70 DAI (within 1% maxAmount of 7000 DAI)

        vm.prank(AI_AGENT);
        PortfolioRebalancer(BOB).executeRebalance(path, amountIn);

        path = new address[](2);
        path[0] = address(tokenDAI);
        path[1] = address(tokenETH);

        amountIn = 60e18; // (within 1% maxAmount of 7000 DAI)

        vm.startPrank(AI_AGENT);
        for (uint256 i = 0; i < 10; i++) {
            PortfolioRebalancer(BOB).executeRebalance(path, amountIn);
        }
        vm.stopPrank();

        // Get balances after rebalancing
        uint256 finalDAI = tokenDAI.balanceOf(BOB);
        uint256 finalETH = tokenETH.balanceOf(BOB);
        uint256 finalBTC = tokenBTC.balanceOf(BOB);

        console2.log("After rebalancing:");
        console2.log("DAI balance:", finalDAI / 1e18);
        console2.log("ETH balance:", finalETH / 1e18);
        console2.log("BTC balance:", finalBTC / 1e18, ",", (finalBTC - 1e18) / 1e14);

        // Verify DAI was reduced
        assertLt(finalDAI, initialDAI, "DAI balance should be reduced");

        // Verify ETH was increased
        assertGt(finalETH, initialETH, "ETH balance should be increased");

        // Verify BTC remained the same
        assertGt(finalBTC, initialBTC, "BTC balance should be increased");

        bool isDisbalanced = PortfolioRebalancer(BOB).ifDisbalanced();
        assertTrue(!isDisbalanced, "Not disbalanced");

        console2.log("Portfolio is balanced after rebalancing: ", isDisbalanced);
        console2.log("Rebalancing completed successfully");
    }

    function createInitializationSignature(
        PortfolioRebalancer.Asset[] memory assets,
        uint256 threshold,
        uint256 maxAmount,
        address _router,
        address _oracle,
        address ai_agent,
        address owner
    ) internal pure returns (bytes memory) {
        // Create the struct hash as defined in the contract
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Init(Asset[] assets,uint256 threshold,uint256 maxAmount,address router,address oracle,address ai_agent,address owner)"
                ),
                keccak256(encodeAssets(assets)),
                threshold,
                maxAmount,
                _router,
                _oracle,
                ai_agent,
                owner
            )
        );

        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(structHash);

        // Sign with the portfolio contract's private key (which is the contract address)
        // For testing, we'll use a deterministic private key based on the contract address
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function encodeAssets(PortfolioRebalancer.Asset[] memory assets) internal pure returns (bytes memory data) {
        for (uint256 i = 0; i < assets.length; i++) {
            data = abi.encodePacked(data, assets[i].token, assets[i].targetBps);
        }
    }
}
