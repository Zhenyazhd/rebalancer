// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 * @dev Тестовый ERC20 токен для использования в тестах EIP-7702
 * Включает функции mint, burn, permit и другие полезные функции для тестирования
 */
contract TestToken is ERC20, ERC20Permit, ERC20Burnable, Ownable {
    // События для отслеживания операций
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event EmergencyWithdraw(address indexed owner, uint256 amount);

    /**
     * @dev Конструктор токена
     * @param initialOwner Адрес владельца контракта
     * @param initialSupply Начальное количество токенов
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
     * @dev Функция для минтинга токенов (только владелец)
     * @param to Адрес получателя
     * @param amount Количество токенов для минтинга
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Функция для массового минтинга токенов (только владелец)
     * @param recipients Массив адресов получателей
     * @param amounts Массив количеств токенов для каждого получателя
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "TestToken: arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Функция для сжигания токенов с адреса (только владелец)
     * @param from Адрес, с которого сжигаются токены
     * @param amount Количество токенов для сжигания
     */
    function burnFrom(address from, uint256 amount) public override onlyOwner {
        super.burnFrom(from, amount);
        emit TokensBurned(from, amount);
    }

    /**
     * @dev Функция для экстренного вывода ETH из контракта (только владелец)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "TestToken: no ETH to withdraw");

        (bool success,) = payable(owner()).call{value: balance}("");
        require(success, "TestToken: ETH transfer failed");

        emit EmergencyWithdraw(owner(), balance);
    }

    /**
     * @dev Функция для проверки баланса и разрешений
     * @param account Адрес для проверки
     * @param spender Адрес спендера
     * @return balance Баланс аккаунта
     * @return allowance Разрешение для спендера
     */
    function getAccountInfo(address account, address spender)
        external
        view
        returns (uint256 balance, uint256 allowance)
    {
        return (balanceOf(account), super.allowance(account, spender));
    }

    /**
     * @dev Функция для получения информации о нескольких аккаунтах
     * @param accounts Массив адресов для проверки
     * @return balances Массив балансов
     */
    function getMultipleBalances(address[] calldata accounts) external view returns (uint256[] memory balances) {
        balances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            balances[i] = balanceOf(accounts[i]);
        }
        return balances;
    }

    /**
     * @dev Функция для тестирования batch transfer
     * @param recipients Массив адресов получателей
     * @param amounts Массив количеств токенов
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "TestToken: arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Функция для тестирования permit и transfer в одной транзакции
     * @param from Адрес отправителя
     * @param to Адрес получателя
     * @param amount Количество токенов
     * @param deadline Дедлайн для permit
     * @param v Компонент подписи
     * @param r Компонент подписи
     * @param s Компонент подписи
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
     * @dev Функция для получения текущего nonce для permit
     * @param owner Адрес владельца
     * @return nonce Текущий nonce
     */
    function getNonce(address owner) external view returns (uint256) {
        return nonces(owner);
    }
}
