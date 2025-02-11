// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SuperFluidFlow.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract FluidFlowFactory is Ownable, ReentrancyGuard {
    // Events
    event FundCreated(address indexed fundAddress, address indexed manager, string name);
    event TokenWhitelisted(address indexed token, bool status);

    // Custom errors
    error InvalidAcceptedToken();
    error ProfitSharingPercentageTooHigh();
    error InvalidSubscriptionEndTime();
    error FundDurationTooShort();
    error InvalidToken();
    error ArrayLengthMismatch();

    // State variables
    mapping(address => bool) public whitelistedTokens;
    mapping(address => bool) public isFund;
    address[] public allFunds;
    ISuperToken public acceptedToken; // make it immutable

    constructor(ISuperToken _acceptedToken) {
        if (address(_acceptedToken) == address(0)) revert InvalidAcceptedToken();
        acceptedToken = _acceptedToken;
    }

    /**
     * @notice Creates a new fund.
     * @param name Name of the fund.
     * @param profitSharingPercentage Percentage of profits that goes to fund manager (in basis points).
     * @param subscriptionEndTime Timestamp after which no new subscriptions are allowed.
     * @param fundDuration Duration of the fund in seconds.
     */
    function createFund(
        string memory name,
        uint256 profitSharingPercentage,
        uint256 subscriptionEndTime,
        uint256 fundDuration
    ) external nonReentrant returns (address) {
        if (profitSharingPercentage > 5000) revert ProfitSharingPercentageTooHigh();
        if (subscriptionEndTime <= block.timestamp) revert InvalidSubscriptionEndTime();

        // Calculate subscription duration
        uint256 subscriptionDuration = subscriptionEndTime - block.timestamp;
        if (fundDuration <= subscriptionDuration) revert FundDurationTooShort();

        // Create fund token name and symbol
        string memory fundTokenName = string(abi.encodePacked("FluidFund"));
        string memory fundTokenSymbol = string(abi.encodePacked("FF", name));

        SuperFluidFlow newFund = new SuperFluidFlow(
            acceptedToken,
            msg.sender, // fund manager
            fundDuration,
            subscriptionDuration,
            address(this), // factory address
            fundTokenName,
            fundTokenSymbol
        );

        address fundAddress = address(newFund);
        isFund[fundAddress] = true;
        allFunds.push(fundAddress);

        emit FundCreated(fundAddress, msg.sender, name);
        return fundAddress;
    }

    /**
     * @notice Whitelist or de-whitelist a token for trading.
     * @param token Token address to whitelist.
     * @param status True to whitelist, false to de-whitelist.
     */
    function setTokenWhitelisted(address token, bool status) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        whitelistedTokens[token] = status;
        emit TokenWhitelisted(token, status);
    }

    /**
     * @notice Batch whitelist or de-whitelist tokens.
     * @param tokens Array of token addresses.
     * @param statuses Array of whitelist statuses.
     */
    // function batchSetTokenWhitelisted(
    //     address[] calldata tokens,
    //     bool[] calldata statuses
    // ) external onlyOwner {
    //     if (tokens.length != statuses.length) revert ArrayLengthMismatch();
    //     for (uint i = 0; i < tokens.length; i++) {
    //         if (tokens[i] == address(0)) revert InvalidToken();
    //         whitelistedTokens[tokens[i]] = statuses[i];
    //         emit TokenWhitelisted(tokens[i], statuses[i]);
    //     }
    // }

    /**
     * @notice Check if a token is whitelisted.
     * @param token Token address to check.
     */
    function isTokenWhitelisted(address token) external view returns (bool) {
        return whitelistedTokens[token];
    }
}

