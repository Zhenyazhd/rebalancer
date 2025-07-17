// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {console} from "forge-std/console.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

/// @notice Delegate contract for an EOA via EIP-7702, which auto‐rebalances its token portfolio.
contract PortfolioRebalancer {
    struct Asset {
        address token;
        uint256 targetBps; // in 10_000
    }

    Asset[] public assets;
    uint256 public rebalanceThresholdBps; // in 10_000, e.g. 500 = 5%
    uint256 public maxAmount; // percent,  100 = 1%
    IUniswapV2Router public router;
    IPriceOracle public oracle;
    address public ai_agent;

    // Flag to prevent double initialization
    bool public initialized;

    address public owner;

    modifier onlyAiAgent() {
        require(msg.sender == ai_agent, "Only AI agent can call this function");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Contract not initialized");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /// @dev Initialize the contract (replaces constructor)
    /// @param _assets      list of tokens + target weights
    /// @param _threshold   deviation threshold in BPS (e.g. 500 = 5%)
    /// @param _maxAmount   max amount percentage
    /// @param _router      address of UniswapV2‐style router
    /// @param _oracle      price oracle returning USDⁱ⁸ per token
    /// @param _ai_agent    AI agent address
    /// @param _owner       contract owner
    function initialize(
        Asset[] memory _assets,
        uint256 _threshold,
        uint256 _maxAmount,
        address _router,
        address _oracle,
        address _ai_agent,
        address _owner,
        bytes calldata signature
    ) external {
        require(!initialized, "Already initialized");
        require(_owner != address(0), "Invalid owner");

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Init(Asset[] assets,uint256 threshold,uint256 maxAmount,address router,address oracle,address ai_agent,address owner)"
                ),
                keccak256(encodeAssets(_assets)), // helper function
                _threshold,
                _maxAmount,
                _router,
                _oracle,
                _ai_agent,
                _owner
            )
        );

        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(structHash);
        address signer = ECDSA.recover(digest, signature);
        require(signer == address(this), "Invalid signature");

        require(_ai_agent != address(0), "Invalid AI agent");
        require(_router != address(0), "Invalid router");
        require(_oracle != address(0), "Invalid oracle");

        rebalanceThresholdBps = _threshold;
        maxAmount = _maxAmount;
        router = IUniswapV2Router(_router);
        oracle = IPriceOracle(_oracle);
        ai_agent = _ai_agent;

        for (uint256 i; i < _assets.length; i++) {
            assets.push(_assets[i]);
        }
        owner = _owner;
        initialized = true;
    }

    function encodeAssets(Asset[] memory _assets) internal pure returns (bytes memory data) {
        for (uint256 i = 0; i < _assets.length; i++) {
            data = abi.encodePacked(data, _assets[i].token, _assets[i].targetBps);
        }
    }

    function ifDisbalanced() external view onlyInitialized returns (bool) {
        uint256 n = assets.length;
        uint256 totalValue = 0;
        uint256[] memory balances = new uint256[](n);
        for (uint256 i; i < n; i++) {
            uint256 bal = IERC20(assets[i].token).balanceOf(address(this));
            uint256 price = oracle.getPrice(assets[i].token);
            uint256 val = (bal * price) / 1e18;
            balances[i] = val;
            totalValue += val;
        }

        for (uint256 i; i < n; i++) {
            uint256 targetValue = (totalValue * assets[i].targetBps) / 10_000;
            uint256 currentVal = balances[i];
            if (
                currentVal > targetValue + ((totalValue * rebalanceThresholdBps) / 10_000)
                    || currentVal + ((totalValue * rebalanceThresholdBps) / 10_000) < targetValue
            ) {
                return true;
            }
        }
        return false;
    }

    /// @dev Swap `amountUsd` worth of `sellToken` into all other tokens proportionally.
    function executeRebalance(address[] memory path, uint256 amountIn) public onlyAiAgent onlyInitialized {
        require((IERC20(path[0]).balanceOf(address(this)) * maxAmount) / 10_000 >= amountIn, "Not enough balance");
        uint256 n = assets.length;
        address tokenOut = path[path.length - 1];
        for (uint256 i; i < n; i++) {
            if (tokenOut == assets[i].token) {
                IERC20(path[0]).approve(address(router), amountIn);
                router.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp + 300);
            }
        }
    }

    /// @dev Update AI agent (only owner)
    function setAiAgent(address _ai_agent) external onlyOwner {
        require(_ai_agent != address(0), "Invalid AI agent");
        ai_agent = _ai_agent;
    }

    /// @dev Update oracle (only owner)
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        oracle = IPriceOracle(_oracle);
    }

    /// @dev Update router (only owner)
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router");
        router = IUniswapV2Router(_router);
    }

    /// @dev Update rebalance threshold (only owner)
    function setRebalanceThreshold(uint256 _threshold) external onlyOwner {
        rebalanceThresholdBps = _threshold;
    }

    /// @dev Update max amount (only owner)
    function setMaxAmount(uint256 _maxAmount) external onlyOwner {
        maxAmount = _maxAmount;
    }
}
