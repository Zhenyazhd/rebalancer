// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 * @dev Test ERC20 token for use in EIP-7702 tests
 * Includes mint, burn, permit and other useful functions for testing
 */
contract TestToken is ERC20, ERC20Permit, ERC20Burnable, Ownable {
    // Events for tracking operations
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event EmergencyWithdraw(address indexed owner, uint256 amount);

    /**
     * @dev Token constructor
     * @param initialOwner Contract owner address
     * @param initialSupply Initial token supply
     */
    constructor(address initialOwner, uint256 initialSupply)
        ERC20("Test Token", "TEST")
        ERC20Permit("Test Token")
        Ownable(initialOwner)
    {
        if (initialSupply > 0) {
            _mint(initialOwner, initialSupply);
        }
    }

    /**
     * @dev Function for minting tokens (owner only)
     * @param to Recipient address
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Function for batch minting tokens (owner only)
     * @param recipients Array of recipient addresses
     * @param amounts Array of token amounts for each recipient
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "TestToken: arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Function for burning tokens from an address (owner only)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) public override onlyOwner {
        super.burnFrom(from, amount);
        emit TokensBurned(from, amount);
    }

    /**
     * @dev Function for emergency ETH withdrawal from contract (owner only)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "TestToken: no ETH to withdraw");

        (bool success,) = payable(owner()).call{value: balance}("");
        require(success, "TestToken: ETH transfer failed");

        emit EmergencyWithdraw(owner(), balance);
    }

    /**
     * @dev Function for checking balance and allowances
     * @param account Address to check
     * @param spender Spender address
     * @return balance Account balance
     * @return allowance Allowance for spender
     */
    function getAccountInfo(address account, address spender)
        external
        view
        returns (uint256 balance, uint256 allowance)
    {
        return (balanceOf(account), super.allowance(account, spender));
    }

    /**
     * @dev Function for getting information about multiple accounts
     * @param accounts Array of addresses to check
     * @return balances Array of balances
     */
    function getMultipleBalances(address[] calldata accounts) external view returns (uint256[] memory balances) {
        balances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            balances[i] = balanceOf(accounts[i]);
        }
        return balances;
    }

    /**
     * @dev Function for testing batch transfer
     * @param recipients Array of recipient addresses
     * @param amounts Array of token amounts
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "TestToken: arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Function for testing permit and transfer in one transaction
     * @param from Sender address
     * @param to Recipient address
     * @param amount Token amount
     * @param deadline Permit deadline
     * @param v Signature component
     * @param r Signature component
     * @param s Signature component
     */
    function permitAndTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        permit(from, address(this), amount, deadline, v, r, s);
        transferFrom(from, to, amount);
    }

    /**
     * @dev Function for getting current nonce for permit
     * @param owner Owner address
     * @return nonce Current nonce
     */
    function getNonce(address owner) external view returns (uint256) {
        return nonces(owner);
    }
}
