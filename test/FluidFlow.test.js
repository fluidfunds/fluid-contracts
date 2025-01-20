const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FluidFlow System", function () {
  // Constants for testing
  const FUND_NAME = "Test Fund";
  const PROFIT_SHARING_BPS = 2000; // 20%
  const MIN_INVESTMENT = ethers.parseEther("1000"); // 1000 USDC
  const MOCK_UNISWAP_ROUTER = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

  async function deployFluidFlowFixture() {
    const ONE_MONTH_IN_SECS = 30 * 24 * 60 * 60;
    const subscriptionEndTime = (await time.latest()) + ONE_MONTH_IN_SECS;

    // Get signers
    const [owner, fundManager, investor1, investor2] = await ethers.getSigners();

    // Deploy mock contracts for testing
    const MockSuperfluid = await ethers.getContractFactory("MockSuperfluid");
    const mockHost = await MockSuperfluid.deploy();

    const MockCFA = await ethers.getContractFactory("MockCFA");
    const mockCFA = await MockCFA.deploy();

    const MockUSDCx = await ethers.getContractFactory("MockUSDCx");
    const mockUSDCx = await MockUSDCx.deploy();

    // Deploy FluidFlowFactory
    const FluidFlowFactory = await ethers.getContractFactory("FluidFlowFactory");
    const factory = await FluidFlowFactory.deploy();

    // Create a fund through the factory
    const createFundTx = await factory.connect(fundManager).createFund(
      FUND_NAME,
      PROFIT_SHARING_BPS,
      subscriptionEndTime,
      MIN_INVESTMENT
    );
    const receipt = await createFundTx.wait();
    const fundCreatedEvent = receipt.events.find(e => e.event === "FundCreated");
    const fundAddress = fundCreatedEvent.args.fundAddress;
    const fund = await ethers.getContractAt("FluidFlow", fundAddress);

    return {
      factory,
      fund,
      mockHost,
      mockCFA,
      mockUSDCx,
      subscriptionEndTime,
      owner,
      fundManager,
      investor1,
      investor2
    };
  }

  describe("FluidFlowFactory", function () {
    describe("Deployment", function () {
      it("Should set the right owner", async function () {
        const { factory, owner } = await loadFixture(deployFluidFlowFixture);
        expect(await factory.owner()).to.equal(owner.address);
      });

      it("Should allow whitelisting tokens", async function () {
        const { factory, owner } = await loadFixture(deployFluidFlowFixture);
        const mockToken = "0x1234567890123456789012345678901234567890";
        
        await factory.connect(owner).setTokenWhitelisted(mockToken, true);
        expect(await factory.isTokenWhitelisted(mockToken)).to.be.true;
      });

      it("Should not allow non-owners to whitelist tokens", async function () {
        const { factory, investor1 } = await loadFixture(deployFluidFlowFixture);
        const mockToken = "0x1234567890123456789012345678901234567890";
        
        await expect(
          factory.connect(investor1).setTokenWhitelisted(mockToken, true)
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });
    });

    describe("Fund Creation", function () {
      it("Should create a new fund with correct parameters", async function () {
        const { factory, fundManager } = await loadFixture(deployFluidFlowFixture);
        const ONE_MONTH_IN_SECS = 30 * 24 * 60 * 60;
        const subscriptionEndTime = (await time.latest()) + ONE_MONTH_IN_SECS;

        const tx = await factory.connect(fundManager).createFund(
          FUND_NAME,
          PROFIT_SHARING_BPS,
          subscriptionEndTime,
          MIN_INVESTMENT
        );

        await expect(tx)
          .to.emit(factory, "FundCreated")
          .withArgs(anyValue, fundManager.address, FUND_NAME);
      });

      it("Should not allow creation with invalid profit sharing", async function () {
        const { factory, fundManager } = await loadFixture(deployFluidFlowFixture);
        const ONE_MONTH_IN_SECS = 30 * 24 * 60 * 60;
        const subscriptionEndTime = (await time.latest()) + ONE_MONTH_IN_SECS;

        await expect(
          factory.connect(fundManager).createFund(
            FUND_NAME,
            6000, // 60% > 50% max
            subscriptionEndTime,
            MIN_INVESTMENT
          )
        ).to.be.revertedWith("Profit share cannot exceed 50%");
      });
    });
  });

  describe("FluidFlow", function () {
    describe("Initialization", function () {
      it("Should initialize with correct parameters", async function () {
        const { fund, fundManager } = await loadFixture(deployFluidFlowFixture);
        
        expect(await fund.name()).to.equal(FUND_NAME);
        expect(await fund.fundManager()).to.equal(fundManager.address);
        expect(await fund.profitSharingBps()).to.equal(PROFIT_SHARING_BPS);
        expect(await fund.minInvestmentAmount()).to.equal(MIN_INVESTMENT);
      });
    });

    describe("Streaming", function () {
      it("Should allow starting a stream with sufficient flow rate", async function () {
        const { fund, investor1, mockHost } = await loadFixture(deployFluidFlowFixture);
        const flowRate = ethers.parseEther("40"); // 40 USDC per second = ~1200 USDC per month

        await expect(fund.connect(investor1).updateStream(flowRate))
          .to.emit(fund, "StreamStarted")
          .withArgs(investor1.address, flowRate);
      });

      it("Should not allow stream with insufficient flow rate", async function () {
        const { fund, investor1 } = await loadFixture(deployFluidFlowFixture);
        const flowRate = ethers.parseEther("0.1"); // Too low

        await expect(
          fund.connect(investor1).updateStream(flowRate)
        ).to.be.revertedWith("Flow rate too low for min investment");
      });
    });

    describe("Trading", function () {
      it("Should allow fund manager to execute trades with whitelisted tokens", async function () {
        const { fund, factory, fundManager, owner } = await loadFixture(deployFluidFlowFixture);
        const mockTokenIn = "0x1234567890123456789012345678901234567890";
        const mockTokenOut = "0x0987654321098765432109876543210987654321";
        
        // Whitelist tokens
        await factory.connect(owner).setTokenWhitelisted(mockTokenIn, true);
        await factory.connect(owner).setTokenWhitelisted(mockTokenOut, true);

        await expect(
          fund.connect(fundManager).executeTrade(
            mockTokenIn,
            mockTokenOut,
            ethers.parseEther("100"),
            ethers.parseEther("95")
          )
        ).to.emit(fund, "TradeExecuted");
      });

      it("Should not allow trading non-whitelisted tokens", async function () {
        const { fund, fundManager } = await loadFixture(deployFluidFlowFixture);
        const mockTokenIn = "0x1234567890123456789012345678901234567890";
        const mockTokenOut = "0x0987654321098765432109876543210987654321";

        await expect(
          fund.connect(fundManager).executeTrade(
            mockTokenIn,
            mockTokenOut,
            ethers.parseEther("100"),
            ethers.parseEther("95")
          )
        ).to.be.revertedWith("Token not whitelisted");
      });
    });

    describe("Profit Realization", function () {
      it("Should correctly realize profits and distribute fees", async function () {
        const { fund, fundManager } = await loadFixture(deployFluidFlowFixture);
        const totalValue = ethers.parseEther("1200"); // 1200 USDC
        const initialInvestment = ethers.parseEther("1000"); // 1000 USDC

        // Set initial investment (would normally come through streams)
        // This would need a helper function in the contract for testing

        await expect(fund.connect(fundManager).realizeProfits(totalValue))
          .to.emit(fund, "ProfitsRealized");
      });
    });

    describe("Withdrawals", function () {
      it("Should not allow withdrawal with active stream", async function () {
        const { fund, investor1 } = await loadFixture(deployFluidFlowFixture);
        const flowRate = ethers.parseEther("40");
        
        // Start a stream
        await fund.connect(investor1).updateStream(flowRate);

        // Try to withdraw
        await expect(
          fund.connect(investor1).withdraw(ethers.parseEther("100"))
        ).to.be.revertedWith("Stop stream before withdrawal");
      });
    });
  });
}); 