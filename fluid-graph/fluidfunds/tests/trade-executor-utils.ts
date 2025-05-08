import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  OwnershipTransferred,
  SwapExecuted,
  TokenWhitelistStatusUpdated,
  UniswapV3RouterUpdated
} from "../generated/TradeExecutor/TradeExecutor"

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent =
    changetype<OwnershipTransferred>(newMockEvent())

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createSwapExecutedEvent(
  tokenIn: Address,
  tokenOut: Address,
  amountIn: BigInt,
  amountOut: BigInt,
  trader: Address
): SwapExecuted {
  let swapExecutedEvent = changetype<SwapExecuted>(newMockEvent())

  swapExecutedEvent.parameters = new Array()

  swapExecutedEvent.parameters.push(
    new ethereum.EventParam("tokenIn", ethereum.Value.fromAddress(tokenIn))
  )
  swapExecutedEvent.parameters.push(
    new ethereum.EventParam("tokenOut", ethereum.Value.fromAddress(tokenOut))
  )
  swapExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "amountIn",
      ethereum.Value.fromUnsignedBigInt(amountIn)
    )
  )
  swapExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "amountOut",
      ethereum.Value.fromUnsignedBigInt(amountOut)
    )
  )
  swapExecutedEvent.parameters.push(
    new ethereum.EventParam("trader", ethereum.Value.fromAddress(trader))
  )

  return swapExecutedEvent
}

export function createTokenWhitelistStatusUpdatedEvent(
  token: Address,
  status: boolean
): TokenWhitelistStatusUpdated {
  let tokenWhitelistStatusUpdatedEvent =
    changetype<TokenWhitelistStatusUpdated>(newMockEvent())

  tokenWhitelistStatusUpdatedEvent.parameters = new Array()

  tokenWhitelistStatusUpdatedEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  tokenWhitelistStatusUpdatedEvent.parameters.push(
    new ethereum.EventParam("status", ethereum.Value.fromBoolean(status))
  )

  return tokenWhitelistStatusUpdatedEvent
}

export function createUniswapV3RouterUpdatedEvent(
  oldRouter: Address,
  newRouter: Address
): UniswapV3RouterUpdated {
  let uniswapV3RouterUpdatedEvent =
    changetype<UniswapV3RouterUpdated>(newMockEvent())

  uniswapV3RouterUpdatedEvent.parameters = new Array()

  uniswapV3RouterUpdatedEvent.parameters.push(
    new ethereum.EventParam("oldRouter", ethereum.Value.fromAddress(oldRouter))
  )
  uniswapV3RouterUpdatedEvent.parameters.push(
    new ethereum.EventParam("newRouter", ethereum.Value.fromAddress(newRouter))
  )

  return uniswapV3RouterUpdatedEvent
}
