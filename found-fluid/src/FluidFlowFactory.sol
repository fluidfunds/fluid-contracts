// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SuperFluidFlow.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ISuperTokenFactory } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import "./PureSuperToken.sol";
import "./interfaces/IFluidFlowStorage.sol";
import "./interfaces/IFluidFlowStorageFactory.sol";

contract FluidFlowFactory is Ownable, ReentrancyGuard {
    // Events
    event FundCreated(address indexed fundAddress, address indexed manager, string name, uint256 fee, uint256 startTime, uint256 duration);

    // Custom errors
    error InvalidAcceptedToken();
    error InvalidToken();
    error ArrayLengthMismatch();

    ISuperToken public acceptedToken;
    address public tradeExec;
    IFluidFlowStorageFactory public storageFactory;


    /**
     * @dev Initialize the contract with necessary components
     * @notice This can only be called once during deployment
     * @param _tradeExec Address of the trade executor contract
     * @param _storageFactory Address of the storage factory contract
     */
    constructor(address _tradeExec, IFluidFlowStorageFactory _storageFactory) {
        tradeExec = _tradeExec;
        
        // Set the storage factory
        storageFactory = _storageFactory;
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
        string memory fundTokenSymbol = string(abi.encodePacked("FF", name));

        SuperFluidFlow newFund = new SuperFluidFlow(
            ISuperfluid(acceptedToken.getHost())
        );
        
        // Get address of new fund
        address fundAddress = address(newFund);
        
        // Create storage for this fund using the factory
        address storageAddress = storageFactory.createStorage(fundAddress, block.timestamp + fundDuration);

        newFund.initialize(
            acceptedToken,
            msg.sender, // fund manager
            fundDuration,
            subscriptionDuration,
            address(this), // factory address
            fundTokenSymbol,
            tradeExec,
            IFluidFlowStorage(storageAddress)
        );

        emit FundCreated(fundAddress, msg.sender, name, profitSharingPercentage, subscriptionDuration, fundDuration);
        return fundAddress;
    }

}
