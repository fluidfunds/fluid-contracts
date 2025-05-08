import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { FundClosed } from "../generated/schema"
import { FundClosed as FundClosedEvent } from "../generated/SuperFluidFlow/SuperFluidFlow"
import { handleFundClosed } from "../src/super-fluid-flow"
import { createFundClosedEvent } from "./super-fluid-flow-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let newFundClosedEvent = createFundClosedEvent()
    handleFundClosed(newFundClosedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("FundClosed created and stored", () => {
    assert.entityCount("FundClosed", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
