// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract MockSuperfluid {
    function callAgreement(
        address agreementClass,
        bytes memory callData,
        bytes memory userData
    ) external returns (bytes memory returnedData) {
        // Mock implementation that always succeeds
        return "";
    }
} 