import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  FundCreated,
  OwnershipTransferred
} from "../generated/FluidFlowFactory/FluidFlowFactory"

export function createFundCreatedEvent(
  fundAddress: Address,
  manager: Address,
  name: string
): FundCreated {
  let fundCreatedEvent = changetype<FundCreated>(newMockEvent())

  fundCreatedEvent.parameters = new Array()

  fundCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "fundAddress",
      ethereum.Value.fromAddress(fundAddress)
    )
  )
  fundCreatedEvent.parameters.push(
    new ethereum.EventParam("manager", ethereum.Value.fromAddress(manager))
  )
  fundCreatedEvent.parameters.push(
    new ethereum.EventParam("name", ethereum.Value.fromString(name))
  )

  return fundCreatedEvent
}

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
