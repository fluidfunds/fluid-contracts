import {
  FundClosed as FundClosedEvent,
  FundFlow as FundFlowEvent,
  PositionClosed as PositionClosedEvent,
  TradeExecuted as TradeExecutedEvent,
  UserLiquidated as UserLiquidatedEvent,
  UserWithdrawn as UserWithdrawnEvent,
} from "../generated/SuperFluidFlow/SuperFluidFlow"
import {
  FundClosed,
  FundFlow,
  PositionClosed,
  TradeExecuted,
  UserLiquidated,
  UserWithdrawn,
} from "../generated/schema"

export function handleFundClosed(event: FundClosedEvent): void {
  let entity = new FundClosed(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleFundFlow(event: FundFlowEvent): void {
  let entity = new FundFlow(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity._acceptedToken = event.params._acceptedToken
  entity._fundManager = event.params._fundManager
  entity._fundDuration = event.params._fundDuration
  entity._subscriptionDuration = event.params._subscriptionDuration
  entity._factory = event.params._factory
  entity._fundTokenSymbol = event.params._fundTokenSymbol

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePositionClosed(event: PositionClosedEvent): void {
  let entity = new PositionClosed(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.positionId = event.params.positionId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTradeExecuted(event: TradeExecutedEvent): void {
  let entity = new TradeExecuted(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.tokenIn = event.params.tokenIn
  entity.tokenOut = event.params.tokenOut
  entity.amountIn = event.params.amountIn
  entity.amountOut = event.params.amountOut
  entity.timestamp = event.params.timestamp
  entity.isOpen = event.params.isOpen

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUserLiquidated(event: UserLiquidatedEvent): void {
  let entity = new UserLiquidated(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.user = event.params.user
  entity.tokenBalance = event.params.tokenBalance
  entity.amountTaken = event.params.amountTaken

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUserWithdrawn(event: UserWithdrawnEvent): void {
  let entity = new UserWithdrawn(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.user = event.params.user
  entity.fundTokensRedeemed = event.params.fundTokensRedeemed
  entity.amountReceived = event.params.amountReceived

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
