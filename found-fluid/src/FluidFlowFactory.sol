// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SuperFluidFlow.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ISuperTokenFactory } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import "./PureSuperToken.sol";

contract FluidFlowFactory is Ownable, ReentrancyGuard {
    // Events
    event FundCreated(address indexed fundAddress, address indexed manager, string name, uint256 fee, uint256 startTime, uint256 duration);

    // Custom errors
    error InvalidAcceptedToken();
    error InvalidToken();
    error ArrayLengthMismatch();

    ISuperToken public acceptedToken;
    address public tradeExec;


    constructor(ISuperfluid _host, address _tradeExec) {
        // Deploy new PureSuperTokenProxy for the accepted token
        PureSuperTokenProxy tokenProxy = new PureSuperTokenProxy();
        
        // Get SuperToken factory from host
        ISuperTokenFactory superTokenFactory = ISuperTokenFactory(_host.getSuperTokenFactory());
        
        // Initialize the token with initial supply
        uint256 initialSupply = 1_000_000_000 * 1e18; // 1 billion tokens
        tokenProxy.initialize(
            superTokenFactory,
            "Accepted Token",
            "ATK",
            msg.sender, // Owner receives initial supply
            initialSupply
        );
        
        acceptedToken = ISuperToken(address(tokenProxy));
        tradeExec = _tradeExec;

    }


    /**
     * @notice Creates a new fund.
     * @param name Name of the fund.
     * @param profitSharingPercentage Percentage of profits that goes to fund manager (in basis points).
     * @param subscriptionDuration Duration of the subscription in seconds.
     * @param fundDuration Duration of the fund in seconds.
     */
    function createFund(
        string memory name,
        uint256 profitSharingPercentage,
        uint256 subscriptionDuration,
        uint256 fundDuration,
        ISuperToken _acceptedToken
    ) external nonReentrant returns (address) {
        acceptedToken = _acceptedToken;

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

        emit FundCreated(fundAddress, msg.sender, name, profitSharingPercentage, subscriptionDuration, fundDuration);
        return fundAddress;
    }

    function withdrawEmergency(SuperFluidFlow fundAddr, IERC20 token) public onlyOwner {
        fundAddr.withdrawEmergency(token);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }


}

