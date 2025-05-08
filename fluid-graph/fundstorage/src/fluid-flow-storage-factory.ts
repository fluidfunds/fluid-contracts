import {
  OwnershipTransferred as OwnershipTransferredEvent,
  StorageCreated as StorageCreatedEvent
} from "../generated/FluidFlowStorageFactory/FluidFlowStorageFactory"
import { OwnershipTransferred, StorageCreated } from "../generated/schema"

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

export function handleStorageCreated(event: StorageCreatedEvent): void {
  let entity = new StorageCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.storageAddress = event.params.storageAddress
  entity.fundAddress = event.params.fundAddress

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
