import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { FundCreated } from "../generated/schema"
import { FundCreated as FundCreatedEvent } from "../generated/FluidFlowFactory/FluidFlowFactory"
import { handleFundCreated } from "../src/fluid-flow-factory"
import { createFundCreatedEvent } from "./fluid-flow-factory-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let fundAddress = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let manager = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let name = "Example string value"
    let fee = BigInt.fromI32(234)
    let startTime = BigInt.fromI32(234)
    let duration = BigInt.fromI32(234)
    let newFundCreatedEvent = createFundCreatedEvent(
      fundAddress,
      manager,
      name,
      fee,
      startTime,
      duration
    )
    handleFundCreated(newFundCreatedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("FundCreated created and stored", () => {
    assert.entityCount("FundCreated", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "FundCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "fundAddress",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "FundCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "manager",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "FundCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "name",
      "Example string value"
    )
    assert.fieldEquals(
      "FundCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "fee",
      "234"
    )
    assert.fieldEquals(
      "FundCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "startTime",
      "234"
    )
    assert.fieldEquals(
      "FundCreated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "duration",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
