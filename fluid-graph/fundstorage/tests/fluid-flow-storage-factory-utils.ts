import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  OwnershipTransferred,
  StorageCreated
} from "../generated/FluidFlowStorageFactory/FluidFlowStorageFactory"

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

export function createStorageCreatedEvent(
  storageAddress: Address,
  fundAddress: Address
): StorageCreated {
  let storageCreatedEvent = changetype<StorageCreated>(newMockEvent())

  storageCreatedEvent.parameters = new Array()

  storageCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "storageAddress",
      ethereum.Value.fromAddress(storageAddress)
    )
  )
  storageCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "fundAddress",
      ethereum.Value.fromAddress(fundAddress)
    )
  )

  return storageCreatedEvent
}
