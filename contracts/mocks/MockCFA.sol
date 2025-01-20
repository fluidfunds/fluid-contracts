// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

contract MockCFA {
    function createFlow(
        address token,
        address receiver,
        int96 flowRate,
        bytes memory ctx
    ) external returns (bytes memory newCtx) {
        // Mock implementation that always succeeds
        return "";
    }

    function updateFlow(
        address token,
        address receiver,
        int96 flowRate,
        bytes memory ctx
    ) external returns (bytes memory newCtx) {
        // Mock implementation that always succeeds
        return "";
    }

    function deleteFlow(
        address token,
        address sender,
        address receiver,
        bytes memory ctx
    ) external returns (bytes memory newCtx) {
        // Mock implementation that always succeeds
        return "";
    }
} 