import {
  OwnershipTransferred as OwnershipTransferredEvent,
  SwapExecuted as SwapExecutedEvent,
  TokenWhitelistStatusUpdated as TokenWhitelistStatusUpdatedEvent,
  UniswapV3RouterUpdated as UniswapV3RouterUpdatedEvent,
} from "../generated/TradeExecutor/TradeExecutor"
import {
  OwnershipTransferred,
  SwapExecuted,
  TokenWhitelistStatusUpdated,
  UniswapV3RouterUpdated,
} from "../generated/schema"

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent,
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSwapExecuted(event: SwapExecutedEvent): void {
  let entity = new SwapExecuted(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.tokenIn = event.params.tokenIn
  entity.tokenOut = event.params.tokenOut
  entity.amountIn = event.params.amountIn
  entity.amountOut = event.params.amountOut
  entity.trader = event.params.trader

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTokenWhitelistStatusUpdated(
  event: TokenWhitelistStatusUpdatedEvent,
): void {
  let entity = new TokenWhitelistStatusUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.token = event.params.token
  entity.status = event.params.status

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleUniswapV3RouterUpdated(
  event: UniswapV3RouterUpdatedEvent,
): void {
  let entity = new UniswapV3RouterUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.oldRouter = event.params.oldRouter
  entity.newRouter = event.params.newRouter

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
