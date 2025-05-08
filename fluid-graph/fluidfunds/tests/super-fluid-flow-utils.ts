import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  FundClosed,
  FundFlow,
  PositionClosed,
  TradeExecuted,
  UserLiquidated,
  UserWithdrawn
} from "../generated/SuperFluidFlow/SuperFluidFlow"

export function createFundClosedEvent(): FundClosed {
  let fundClosedEvent = changetype<FundClosed>(newMockEvent())

  fundClosedEvent.parameters = new Array()

  return fundClosedEvent
}

export function createFundFlowEvent(
  _acceptedToken: Address,
  _fundManager: Address,
  _fundDuration: BigInt,
  _subscriptionDuration: BigInt,
  _factory: Address,
  _fundTokenSymbol: string
): FundFlow {
  let fundFlowEvent = changetype<FundFlow>(newMockEvent())

  fundFlowEvent.parameters = new Array()

  fundFlowEvent.parameters.push(
    new ethereum.EventParam(
      "_acceptedToken",
      ethereum.Value.fromAddress(_acceptedToken)
    )
  )
  fundFlowEvent.parameters.push(
    new ethereum.EventParam(
      "_fundManager",
      ethereum.Value.fromAddress(_fundManager)
    )
  )
  fundFlowEvent.parameters.push(
    new ethereum.EventParam(
      "_fundDuration",
      ethereum.Value.fromUnsignedBigInt(_fundDuration)
    )
  )
  fundFlowEvent.parameters.push(
    new ethereum.EventParam(
      "_subscriptionDuration",
      ethereum.Value.fromUnsignedBigInt(_subscriptionDuration)
    )
  )
  fundFlowEvent.parameters.push(
    new ethereum.EventParam("_factory", ethereum.Value.fromAddress(_factory))
  )
  fundFlowEvent.parameters.push(
    new ethereum.EventParam(
      "_fundTokenSymbol",
      ethereum.Value.fromString(_fundTokenSymbol)
    )
  )

  return fundFlowEvent
}

export function createPositionClosedEvent(positionId: BigInt): PositionClosed {
  let positionClosedEvent = changetype<PositionClosed>(newMockEvent())

  positionClosedEvent.parameters = new Array()

  positionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "positionId",
      ethereum.Value.fromUnsignedBigInt(positionId)
    )
  )

  return positionClosedEvent
}

export function createTradeExecutedEvent(
  tokenIn: Address,
  tokenOut: Address,
  amountIn: BigInt,
  amountOut: BigInt,
  timestamp: BigInt,
  isOpen: boolean
): TradeExecuted {
  let tradeExecutedEvent = changetype<TradeExecuted>(newMockEvent())

  tradeExecutedEvent.parameters = new Array()

  tradeExecutedEvent.parameters.push(
    new ethereum.EventParam("tokenIn", ethereum.Value.fromAddress(tokenIn))
  )
  tradeExecutedEvent.parameters.push(
    new ethereum.EventParam("tokenOut", ethereum.Value.fromAddress(tokenOut))
  )
  tradeExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "amountIn",
      ethereum.Value.fromUnsignedBigInt(amountIn)
    )
  )
  tradeExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "amountOut",
      ethereum.Value.fromUnsignedBigInt(amountOut)
    )
  )
  tradeExecutedEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )
  tradeExecutedEvent.parameters.push(
    new ethereum.EventParam("isOpen", ethereum.Value.fromBoolean(isOpen))
  )

  return tradeExecutedEvent
}

export function createUserLiquidatedEvent(
  user: Address,
  tokenBalance: BigInt,
  amountTaken: BigInt
): UserLiquidated {
  let userLiquidatedEvent = changetype<UserLiquidated>(newMockEvent())

  userLiquidatedEvent.parameters = new Array()

  userLiquidatedEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  userLiquidatedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenBalance",
      ethereum.Value.fromUnsignedBigInt(tokenBalance)
    )
  )
  userLiquidatedEvent.parameters.push(
    new ethereum.EventParam(
      "amountTaken",
      ethereum.Value.fromUnsignedBigInt(amountTaken)
    )
  )

  return userLiquidatedEvent
}

export function createUserWithdrawnEvent(
  user: Address,
  fundTokensRedeemed: BigInt,
  amountReceived: BigInt
): UserWithdrawn {
  let userWithdrawnEvent = changetype<UserWithdrawn>(newMockEvent())

  userWithdrawnEvent.parameters = new Array()

  userWithdrawnEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  userWithdrawnEvent.parameters.push(
    new ethereum.EventParam(
      "fundTokensRedeemed",
      ethereum.Value.fromUnsignedBigInt(fundTokensRedeemed)
    )
  )
  userWithdrawnEvent.parameters.push(
    new ethereum.EventParam(
      "amountReceived",
      ethereum.Value.fromUnsignedBigInt(amountReceived)
    )
  )

  return userWithdrawnEvent
}
