// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
interface IFluidFlowFactory {

    function isTokenWhitelisted(address token) external view returns (bool);
    
}