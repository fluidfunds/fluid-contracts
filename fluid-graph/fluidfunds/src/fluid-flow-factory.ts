import {
  FundCreated as FundCreatedEvent,
  OwnershipTransferred as OwnershipTransferredEvent
} from "../generated/FluidFlowFactory/FluidFlowFactory"
import { FundCreated, OwnershipTransferred } from "../generated/schema"

export function handleFundCreated(event: FundCreatedEvent): void {
  let entity = new FundCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.fundAddress = event.params.fundAddress
  entity.manager = event.params.manager
  entity.name = event.params.name
  entity.fee = event.params.fee
  entity.startTime = event.params.startTime
  entity.duration = event.params.duration

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
