// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FluidFlow.sol";

contract FluidFlowFactory is Ownable, ReentrancyGuard {
    // Events
    event FundCreated(address indexed fundAddress, address indexed manager, string name);
    event TokenWhitelisted(address indexed token, bool status);

    // State variables
    mapping(address => bool) public whitelistedTokens;
    mapping(address => bool) public isFund;
    address[] public allFunds;

    address public host;
    address public cfa;
    address public usdcx;

    constructor(
        address _host,
        address _cfa,
        address _usdcx
    )  {
        require(_host != address(0), "Invalid host address");
        require(_cfa != address(0), "Invalid CFA address");
        require(_usdcx != address(0), "Invalid USDCx address");
        host = _host;
        cfa = _cfa;
        usdcx = _usdcx;
    }

    /**
     * @notice Creates a new fund
     * @param name Name of the fund
     * @param profitSharingPercentage Percentage of profits that goes to fund manager (in basis points, e.g. 2000 = 20%)
     * @param subscriptionEndTime Timestamp after which no new subscriptions are allowed
     * @param minInvestmentAmount Minimum amount required to invest in the fund
     */
    function createFund(
        string memory name,
        uint256 profitSharingPercentage,
        uint256 subscriptionEndTime,
        uint256 minInvestmentAmount
    ) external nonReentrant returns (address) {
        require(profitSharingPercentage <= 5000, "Profit share cannot exceed 50%");
        require(subscriptionEndTime > block.timestamp, "Invalid subscription end time");

        FluidFlow newFund = new FluidFlow(
            acceptedToken,
            msg.sender, // fund manager
            fundDuration,
            subscriptionDuration,
            fundToken,
            address(this) // pass factory address
        );

        address fundAddress = address(newFund);
        isFund[fundAddress] = true;
        allFunds.push(fundAddress);

        emit FundCreated(fundAddress, msg.sender, name);
        return fundAddress;
    }

    /**
     * @notice Whitelist or de-whitelist a token for trading
     * @param token Token address to whitelist
     * @param status True to whitelist, false to de-whitelist
     */
    function setTokenWhitelisted(address token, bool status) external onlyOwner {
        require(token != address(0), "Invalid token address");
        whitelistedTokens[token] = status;
        emit TokenWhitelisted(token, status);
    }

    /**
     * @notice Batch whitelist or de-whitelist tokens
     * @param tokens Array of token addresses
     * @param statuses Array of whitelist statuses
     */
    function batchSetTokenWhitelisted(
        address[] calldata tokens,
        bool[] calldata statuses
    ) external onlyOwner {
        require(tokens.length == statuses.length, "Array lengths must match");
        for (uint i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token address");
            whitelistedTokens[tokens[i]] = statuses[i];
            emit TokenWhitelisted(tokens[i], statuses[i]);
        }
    }

    /**
     * @notice Check if a token is whitelisted
     * @param token Token address to check
     */
    function isTokenWhitelisted(address token) external view returns (bool) {
        return whitelistedTokens[token];
    }

}

