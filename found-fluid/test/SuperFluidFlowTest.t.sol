// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {SuperFluidFlow} from "../src/SuperFluidFlow.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ITradeExecutor} from "../src/interfaces/ITradeExecutor.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.t.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";

/// @dev A minimal mock implementation of a SuperToken based on ERC20.
contract MockSuperToken is ERC20, ISuperToken {
    mapping(address => int96) public flowRates;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setFlowRate(address user, int96 rate) external {
        flowRates[user] = rate;
    }

    function getFlowRate(address /*sender*/, address /*receiver*/) external view override returns (int96) {
        // For simplicity, always return 100 (or you could later use flowRates if needed)
        return 100;
    }

    function downgrade(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    // The following functions simulate SuperToken "flow" methods.
    function createFlowWithCtx(address /*receiver*/, int96 /*rate*/, bytes calldata ctx) external returns (bytes memory) {
        return ctx;
    }
    function updateFlowWithCtx(address /*receiver*/, int96 /*rate*/, bytes calldata ctx) external returns (bytes memory) {
        return ctx;
    }
    function deleteFlowWithCtx(address /*sender*/, address /*receiver*/, bytes calldata ctx) external returns (bytes memory) {
        return ctx;
    }
}

/// @dev A minimal mock implementation of a SuperToken factory.
contract MockSuperTokenFactory is ISuperTokenFactory {
    function initializeCustomSuperToken(address /*token*/) external override {
        // No-op for testing.
    }
}

/// @dev A minimal mock implementation of the ISuperfluid host.
contract MockSuperfluid is ISuperfluid {
    address public factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function getSuperTokenFactory() external view override returns (address) {
        return factory;
    }
    // Other functions are not needed for these tests.
}

/// @dev A minimal mock implementation of the TradeExecutor.
contract MockTradeExecutor is ITradeExecutor {
    function executeSwap(
        address /*tokenIn*/,
        address /*tokenOut*/,
        uint256 /*amountIn*/,
        uint256 minAmountOut,
        uint24 /*fee*/
    ) external override returns (uint256 amountOut) {
        // Simply return the minimum amount out for testing.
        return minAmountOut;
    }

    function setWhitelistedToken(address /*_token*/, bool /*_status*/) external override {
        // No-op.
    }

    function UNISWAP_V3_ROUTER() external view override returns (address) {
        return address(0);
    }
    function whitelistedTokens(address /*token*/) external view override returns (bool) {
        return true;
    }
}

contract SuperFluidFlowTest is Test {
    SuperFluidFlow public superFluidFlow;
    SuperfluidFrameworkDeployer.Framework private sf;
    ISuperToken public acceptedToken;
    MockTradeExecutor public tradeExecutor;
    address public fundManager = address(1);
    address public owner;
    using SuperTokenV1Library for ISuperToken;

    uint256 public fundDuration = 1000;
    uint256 public subscriptionDuration = 500;

    function setUp() public {
        owner = address(this);
        
        // Deploy Superfluid test framework
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
        sfDeployer.deployTestFramework();
        sf = sfDeployer.getFramework();
        
        // Deploy trade executor
        tradeExecutor = new MockTradeExecutor();

        // Deploy SuperFluidFlow with real Superfluid host
        superFluidFlow = new SuperFluidFlow(sf.host);

        // Create and initialize a test Super Token
        acceptedToken = sf.createSuperToken("Accepted Token", "ATK", 18);
        deal(address(acceptedToken), owner, 1000 * 1e18);

        // Initialize contract
        superFluidFlow.initialize(
            acceptedToken,
            fundManager,
            fundDuration,
            subscriptionDuration,
            address(this),
            "Fund Token",
            "FTK",
            address(tradeExecutor)
        );
    }

    function testInitialization() public {
        // Verify that initialize() correctly sets contract state.
        assertEq(address(superFluidFlow.acceptedToken()), address(acceptedToken));
        assertEq(superFluidFlow.fundManager(), fundManager);
        assertEq(superFluidFlow.isFundActive(), true);
        // Ensure that a fund token has been deployed.
        assertTrue(address(superFluidFlow.fundToken()) != address(0));
    }

    function testExecuteTrade() public {
        // To test executeTrade we first mint some accepted tokens to the SuperFluidFlow.
        acceptedToken.mint(address(superFluidFlow), 500 * 1e18);

        // Call executeTrade as the fund manager.
        vm.prank(fundManager);
        // Expect the TradeExecuted event.
        vm.expectEmit(true, true, false, true);
        emit TradeExecuted(
            address(acceptedToken),
            address(acceptedToken),
            100,
            90,
            block.timestamp,
            true
        );
        superFluidFlow.executeTrade(
            address(acceptedToken),
            address(acceptedToken),
            100,
            90,
            3000
        );
    }

    function testCloseFund() public {
        // Mint tokens into SuperFluidFlow to simulate a profit scenario.
        acceptedToken.mint(address(superFluidFlow), 300);
        // (For simplicity we assume totalStreamed is zero so profit = 300.)
        uint256 initialManagerBalance = acceptedToken.balanceOf(fundManager);
        vm.prank(fundManager);
        superFluidFlow.closeFund();
        uint256 finalManagerBalance = acceptedToken.balanceOf(fundManager);
        // Manager receives 10% of profit: (300 * 10) / 100 = 30.
        assertEq(finalManagerBalance - initialManagerBalance, 30);
        assertTrue(!superFluidFlow.isFundActive());
    }

    function testWithdrawRevertWhenFundActive() public {
        // Calling withdraw() should revert if fund is still active.
        vm.expectRevert(SuperFluidFlow.FundStillActive.selector);
        superFluidFlow.withdraw();
    }

    // Note:
    // Because the fund token is deployed (via PureSuperTokenProxy) in initialize,
    // we "cast" it here to our mock (which has extra testing functions)
    // so as to simulate a subscription flow.
    function testWithdrawSuccess() public {
        // First, close the fund.
        acceptedToken.mint(address(superFluidFlow), 1000);
        vm.prank(fundManager);
        superFluidFlow.closeFund();

        // For testing, let user (address 3) hold some fund tokens.
        MockSuperToken fundToken = MockSuperToken(address(superFluidFlow.fundToken()));
        address user = address(3);
        uint256 userFundTokenAmount = 100 * 1e18;
        // Simulate a subscription by minting some fund tokens directly to the user.
        fundToken.mint(user, userFundTokenAmount);

        // User must approve SuperFluidFlow to burn these tokens.
        vm.prank(user);
        fundToken.approve(address(superFluidFlow), userFundTokenAmount);

        // Record accepted-token balance before withdrawal.
        uint256 acceptedBalanceBefore = acceptedToken.balanceOf(user);

        // User calls withdraw().
        vm.prank(user);
        superFluidFlow.withdraw();

        // Calculate the expected received share.
        uint256 totalFundSupply = fundToken.totalSupply();
        uint256 contractAcceptedBalance = acceptedToken.balanceOf(address(superFluidFlow));
        uint256 expectedShare = (contractAcceptedBalance * userFundTokenAmount) / totalFundSupply;

        uint256 acceptedBalanceAfter = acceptedToken.balanceOf(user);
        assertEq(acceptedBalanceAfter - acceptedBalanceBefore, expectedShare);
    }

    // --- Event declaration for expectEmit ---
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp,
        bool isOpen
    );
}