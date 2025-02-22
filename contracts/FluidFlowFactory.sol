// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SuperFluidFlow.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract FluidFlowFactory is Ownable, ReentrancyGuard {
    // Events
    event FundCreated(address indexed fundAddress, address indexed manager, string name);

    // Custom errors
    error InvalidAcceptedToken();
    // error ProfitSharingPercentageTooHigh();
    // error InvalidSubscriptionEndTime();
    // error FundDurationTooShort();
    error InvalidToken();
    error ArrayLengthMismatch();

    mapping(address => bool) public isFund;
    address[] public allFunds;
    ISuperToken public acceptedToken; // make it immutable
    address public tradeExec;

    constructor(ISuperToken _acceptedToken, address _tradeExec) {
        if (address(_acceptedToken) == address(0)) revert InvalidAcceptedToken();
        acceptedToken = _acceptedToken;
        tradeExec = _tradeExec;
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
        // if (profitSharingPercentage > 5000) revert ProfitSharingPercentageTooHigh();
        // if (subscriptionEndTime <= block.timestamp) revert InvalidSubscriptionEndTime();

        // Calculate subscription duration
        uint256 subscriptionDuration = subscriptionEndTime - block.timestamp;
        // if (fundDuration <= subscriptionDuration) revert FundDurationTooShort();

        // Create fund token name and symbol
        string memory fundTokenName = string(abi.encodePacked("FluidFund"));
        string memory fundTokenSymbol = string(abi.encodePacked("FF", name));

        SuperFluidFlow newFund = new SuperFluidFlow(
            ISuperfluid(acceptedToken.getHost())
        );

        newFund.initialize(
            acceptedToken,
            msg.sender, // fund manager
            fundDuration,
            subscriptionDuration,
            address(this), // factory address
            fundTokenName,
            fundTokenSymbol,
            tradeExec
        );

        address fundAddress = address(newFund);
        isFund[fundAddress] = true;
        allFunds.push(fundAddress);

        emit FundCreated(fundAddress, msg.sender, name);
        return fundAddress;
    }


}

