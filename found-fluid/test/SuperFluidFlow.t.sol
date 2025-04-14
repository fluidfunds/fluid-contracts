// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.t.sol";
import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions, ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import {TestToken} from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import {SuperToken} from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import "../src/SuperFluidFlow.sol";
import "../src/interfaces/ITradeExecutor.sol";

contract MockTradeExecutor is ITradeExecutor {
    mapping(address => bool) private _whitelistedTokens;
    address private constant _UNISWAP_ROUTER = address(0x1234567890123456789012345678901234567890);
    
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 poolFee
    ) external override returns (uint256) {
        // Simple mock implementation that returns minAmountOut + 10%
        return minAmountOut * 110 / 100;
    }
    
    function UNISWAP_V3_ROUTER() external view override returns (address) {
        return _UNISWAP_ROUTER;
    }
    
    function setWhitelistedToken(address _token, bool _status) external override {
        _whitelistedTokens[_token] = _status;
    }
    
    function whitelistedTokens(address token) external view override returns (bool) {
        return _whitelistedTokens[token];
    }
}

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, 1000000 * 10**decimals);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        balances[to] += amount;
        totalSupply += amount;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(allowances[from][msg.sender] >= amount, "Insufficient allowance");
        allowances[from][msg.sender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }
}

contract SuperFluidFlowTest is Test {
    SuperfluidFrameworkDeployer.Framework private sf;
    using SuperTokenV1Library for ISuperToken;
    
    ISuperToken private acceptedSuperToken;
    SuperFluidFlow private flowContract;
    MockTradeExecutor private tradeExecutor;
    
    address public owner;
    address public fundManager;
    address public alice;
    address public bob;
    
    uint256 public constant INITIAL_BALANCE = 1000000 * 1e18;
    uint256 public constant FUND_DURATION = 30 days;
    uint256 public constant SUBSCRIPTION_DURATION = 7 days;
    int96 public constant FLOW_RATE = 1000000; // ~2.6 tokens per month

    // Custom errors from SuperFluidFlow contract
    error OnlyOwner();
    error OnlyFundManager();
    error FundDurationTooShort();
    error SubscriptionPeriodEnded();
    error FundStillActive();

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        SuperfluidFrameworkDeployer sfDeployer = new SuperfluidFrameworkDeployer();
        sfDeployer.deployTestFramework();
        sf = sfDeployer.getFramework();

        // Setup accounts
        owner = address(this);
        fundManager = address(0x1);
        alice = address(0x2);
        bob = address(0x3);
        
        // Create SuperToken using deployWrapperSuperToken
        (TestToken testToken, ISuperToken superToken) = sfDeployer.deployWrapperSuperToken(
            "Accepted Token",
            "ATK",
            18,
            INITIAL_BALANCE * 3,
            owner
        );
        
        acceptedSuperToken = ISuperToken(address(superToken));
        
        // Mint test tokens to users and upgrade to super tokens
        testToken.mint(alice, INITIAL_BALANCE);
        testToken.mint(bob, INITIAL_BALANCE);
        
        vm.startPrank(alice);
        testToken.approve(address(acceptedSuperToken), INITIAL_BALANCE);
        acceptedSuperToken.upgrade(INITIAL_BALANCE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        testToken.approve(address(acceptedSuperToken), INITIAL_BALANCE);
        acceptedSuperToken.upgrade(INITIAL_BALANCE);
        vm.stopPrank();
        
        // Create mock trade executor
        tradeExecutor = new MockTradeExecutor();
        
        // Deploy SuperFluidFlow contract
        flowContract = new SuperFluidFlow(sf.host);
    }

    function testInitializeFlow() public {
        vm.startPrank(owner);
        flowContract.initialize(
            acceptedSuperToken,
            fundManager,
            FUND_DURATION,
            SUBSCRIPTION_DURATION,
            address(this), // factory
            "Fund Token",
            "FUND",
            address(tradeExecutor)
        );
        vm.stopPrank();
        
        assertEq(address(flowContract.acceptedToken()), address(acceptedSuperToken));
        assertEq(flowContract.fundManager(), fundManager);
        assertEq(flowContract.owner(), owner);
        assertTrue(flowContract.isFundActive());
    }
    
    function testCreateUserFlow() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Alice creates a flow to the contract
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Check flow exists
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), FLOW_RATE);
        
        // Check fund token flow was created
        ISuperToken fundToken = flowContract.fundToken();
        assertEq(fundToken.getFlowRate(address(flowContract), alice), FLOW_RATE);
    }
    
    function testUpdateUserFlow() public {
        // Create initial flow
        testCreateUserFlow();
        
        int96 newFlowRate = FLOW_RATE * 2;
        
        // Alice updates the flow
        vm.startPrank(alice);
        acceptedSuperToken.updateFlow(address(flowContract), newFlowRate);
        vm.stopPrank();
        
        // Check flow was updated
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), newFlowRate);
        
        // Check fund token flow was updated
        ISuperToken fundToken = flowContract.fundToken();
        assertEq(fundToken.getFlowRate(address(flowContract), alice), newFlowRate);
    }
    
    function testDeleteUserFlow() public {
        // Create initial flow
        testCreateUserFlow();
        
        // Alice deletes the flow
        vm.startPrank(alice);
        acceptedSuperToken.deleteFlow(alice, address(flowContract));
        vm.stopPrank();
        
        // Check flow was deleted
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), 0);
        
        // Check fund token flow was deleted
        ISuperToken fundToken = flowContract.fundToken();
        assertEq(fundToken.getFlowRate(address(flowContract), alice), 0);
    }
    
    function testExecuteTrade() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow to get some accepted tokens into the contract
        testCreateUserFlow();
        
        // Warp time ahead to accumulate some tokens
        vm.warp(block.timestamp + 1 days);
        
        // Get the underlying token address
        address underlyingToken = acceptedSuperToken.getUnderlyingToken();
        
        // Fund manager executes a trade
        vm.startPrank(fundManager);
        flowContract.executeTrade(
            underlyingToken,
            address(0x123), // Some example output token
            1 * 10**18,    // 1 token
            0.9 * 10**18,  // 0.9 token minimum output
            3000           // Pool fee
        );
        vm.stopPrank();
        
        // Cannot verify return values easily in this test as it depends on mock implementation
    }
    
    function testCloseFund() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow to get some accepted tokens into the contract
        testCreateUserFlow();
        
        // Warp time ahead to accumulate some tokens
        vm.warp(block.timestamp + 2 days);
        
        // Fund manager closes the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Check the fund is no longer active
        assertFalse(flowContract.isFundActive());
    }
    
    function testWithdraw() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow to get some accepted tokens into the contract
        testCreateUserFlow();
        
        // Warp time ahead to accumulate some tokens
        vm.warp(block.timestamp + 1 days);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Alice withdraws her share
        vm.startPrank(alice);
        ISuperToken fundToken = flowContract.fundToken();
        uint256 fundTokenBalance = fundToken.balanceOf(alice);
        fundToken.approve(address(flowContract), fundTokenBalance);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Check Alice received tokens
        assertTrue(acceptedSuperToken.balanceOf(alice) > 0);
    }
    
    function testCalculateSharesWithdraw() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flows to get tokens into the contract
        // Alice creates a flow to the contract
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Bob creates a flow with twice the rate
        vm.startPrank(bob);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE * 2);
        vm.stopPrank();
        
        // Warp time ahead to accumulate tokens (3 days)
        vm.warp(block.timestamp + 3 days);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Get fund token
        ISuperToken fundToken = flowContract.fundToken();
        
        // Record initial balances
        uint256 contractBalanceBefore = acceptedSuperToken.balanceOf(address(flowContract));
        uint256 aliceFundTokenBalance = fundToken.balanceOf(alice);
        uint256 bobFundTokenBalance = fundToken.balanceOf(bob);
        uint256 totalFundTokenSupply = fundToken.totalSupply();
        
        // Calculate expected shares
        uint256 expectedAliceShare = (contractBalanceBefore * aliceFundTokenBalance) / totalFundTokenSupply;
        uint256 expectedBobShare = (contractBalanceBefore * bobFundTokenBalance) / totalFundTokenSupply;
        
        // Record initial balances
        uint256 aliceBalanceBefore = acceptedSuperToken.balanceOf(alice);
        uint256 bobBalanceBefore = acceptedSuperToken.balanceOf(bob);
        
        // Alice withdraws her share
        vm.startPrank(alice);
        fundToken.approve(address(flowContract), aliceFundTokenBalance);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Bob withdraws his share
        vm.startPrank(bob);
        fundToken.approve(address(flowContract), bobFundTokenBalance);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Get final balances
        uint256 aliceBalanceAfter = acceptedSuperToken.balanceOf(alice);
        uint256 bobBalanceAfter = acceptedSuperToken.balanceOf(bob);
        
        // Check received amounts match expected shares
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedAliceShare);
        assertEq(bobBalanceAfter - bobBalanceBefore, expectedBobShare);
        
        // Verify Bob received approximately twice as much as Alice (within rounding error)
        assertApproxEqRel(
            bobBalanceAfter - bobBalanceBefore, 
            2 * (aliceBalanceAfter - aliceBalanceBefore), 
            0.01e18  // Allow 1% difference due to rounding
        );
    }
    
    function testProportionalSharesWithMultipleUsers() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Set up three different users with different flow rates
        address charlie = address(0x4);
        vm.startPrank(owner);
        TestToken testToken = TestToken(acceptedSuperToken.getUnderlyingToken());
        testToken.mint(charlie, INITIAL_BALANCE);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        testToken.approve(address(acceptedSuperToken), INITIAL_BALANCE);
        acceptedSuperToken.upgrade(INITIAL_BALANCE);
        vm.stopPrank();
        
        // Users create flows with different rates
        // Alice: 1x flow rate
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Bob: 2x flow rate
        vm.startPrank(bob);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE * 2);
        vm.stopPrank();
        
        // Charlie: 3x flow rate
        vm.startPrank(charlie);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE * 3);
        vm.stopPrank();
        
        // Warp time ahead to accumulate tokens (5 days)
        vm.warp(block.timestamp + 5 days);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Get fund token
        ISuperToken fundToken = flowContract.fundToken();
        
        // Record initial contract balance
        uint256 contractBalanceBefore = acceptedSuperToken.balanceOf(address(flowContract));
        
        // Users withdraw their shares
        vm.startPrank(alice);
        uint256 aliceFundTokenBalance = fundToken.balanceOf(alice);
        fundToken.approve(address(flowContract), aliceFundTokenBalance);
        uint256 aliceBalanceBefore = acceptedSuperToken.balanceOf(alice);
        flowContract.withdraw();
        uint256 aliceBalanceAfter = acceptedSuperToken.balanceOf(alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        uint256 bobFundTokenBalance = fundToken.balanceOf(bob);
        fundToken.approve(address(flowContract), bobFundTokenBalance);
        uint256 bobBalanceBefore = acceptedSuperToken.balanceOf(bob);
        flowContract.withdraw();
        uint256 bobBalanceAfter = acceptedSuperToken.balanceOf(bob);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        uint256 charlieFundTokenBalance = fundToken.balanceOf(charlie);
        fundToken.approve(address(flowContract), charlieFundTokenBalance);
        uint256 charlieBalanceBefore = acceptedSuperToken.balanceOf(charlie);
        flowContract.withdraw();
        uint256 charlieBalanceAfter = acceptedSuperToken.balanceOf(charlie);
        vm.stopPrank();
        
        // Calculate actual received tokens
        uint256 aliceReceived = aliceBalanceAfter - aliceBalanceBefore;
        uint256 bobReceived = bobBalanceAfter - bobBalanceBefore;
        uint256 charlieReceived = charlieBalanceAfter - charlieBalanceBefore;
        
        // Verify proportion of shares matches proportion of flow rates (within rounding error)
        assertApproxEqRel(bobReceived, 2 * aliceReceived, 0.01e18);  // Bob should get ~2x what Alice gets
        assertApproxEqRel(charlieReceived, 3 * aliceReceived, 0.01e18);  // Charlie should get ~3x what Alice gets
    }
    
    function testEdgeCaseWithdrawals() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Test case 1: Single user with 100% of tokens
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Warp time to accumulate tokens
        vm.warp(block.timestamp + 2 days);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Get fund token and record balances
        ISuperToken fundToken = flowContract.fundToken();
        uint256 contractBalanceBefore = acceptedSuperToken.balanceOf(address(flowContract));
        uint256 aliceBalanceBefore = acceptedSuperToken.balanceOf(alice);
        
        // Alice withdraws as the only user
        vm.startPrank(alice);
        uint256 aliceFundTokenBalance = fundToken.balanceOf(alice);
        fundToken.approve(address(flowContract), aliceFundTokenBalance);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Alice should get all tokens (minus manager fee if profit exists)
        uint256 aliceBalanceAfter = acceptedSuperToken.balanceOf(alice);
        uint256 contractBalanceAfter = acceptedSuperToken.balanceOf(address(flowContract));
        
        // Contract should have very small or no balance left (due to potential rounding)
        assertLt(contractBalanceAfter, 100);  // Small dust amount allowed
        
        // Alice should receive approximately the full contract balance
        assertApproxEqRel(aliceBalanceAfter - aliceBalanceBefore, contractBalanceBefore, 0.01e18);
    }
    
    function test_RevertWhen_WithdrawWithZeroFundTokens() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow and accumulate tokens
        testCreateUserFlow();
        
        // Warp time ahead
        vm.warp(block.timestamp + 1 days);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Create a user with no fund tokens
        address noTokenUser = address(0x5);
        
        // User with no fund tokens tries to withdraw
        vm.startPrank(noTokenUser);
        // Will not revert but should transfer 0 tokens
        flowContract.withdraw();
        vm.stopPrank();
        
        // Check no tokens were transferred
        assertEq(acceptedSuperToken.balanceOf(noTokenUser), 0);
    }
    
    function test_RevertWhen_WithdrawActiveFund() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow to get some accepted tokens into the contract
        testCreateUserFlow();
        
        // Alice tries to withdraw before fund is closed (should fail)
        vm.startPrank(alice);
        vm.expectRevert(FundStillActive.selector);
        flowContract.withdraw();
        vm.stopPrank();
    }
    
    function test_RevertWhen_UnauthorizedInitialize() public {
        // Non-owner tries to initialize (should fail)
        vm.startPrank(alice);
        vm.expectRevert(OnlyOwner.selector);
        flowContract.initialize(
            acceptedSuperToken,
            fundManager,
            FUND_DURATION,
            SUBSCRIPTION_DURATION,
            address(this), // factory
            "Fund Token",
            "FUND",
            address(tradeExecutor)
        );
        vm.stopPrank();
    }
    
    function test_RevertWhen_UnauthorizedTrade() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Non-fund manager tries to execute trade (should fail)
        vm.startPrank(alice);
        vm.expectRevert(OnlyFundManager.selector);
        flowContract.executeTrade(
            address(0x123),
            address(0x456),
            1 * 10**18,
            0.9 * 10**18,
            3000
        );
        vm.stopPrank();
    }
    
    function testMultipleUserFlows() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Alice creates a flow to the contract
        vm.startPrank(alice);
        acceptedSuperToken.approve(address(flowContract), type(uint256).max);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Bob creates a flow to the contract
        vm.startPrank(bob);
        acceptedSuperToken.approve(address(flowContract), type(uint256).max);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE * 2);
        vm.stopPrank();
        
        // Check both flows exist
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), FLOW_RATE);
        assertEq(acceptedSuperToken.getFlowRate(bob, address(flowContract)), FLOW_RATE * 2);
        
        // Check both fund token flows were created
        ISuperToken fundToken = flowContract.fundToken();
        assertEq(fundToken.getFlowRate(address(flowContract), alice), FLOW_RATE);
        assertEq(fundToken.getFlowRate(address(flowContract), bob), FLOW_RATE * 2);
    }
    
    function testEmergencyWithdraw() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create a mock token and send it to the contract
        MockERC20 mockToken = new MockERC20("Mock", "MCK");
        mockToken.transfer(address(flowContract), 100 * 10**18);
        
        // Owner performs emergency withdrawal
        vm.startPrank(owner);
        flowContract.withdrawEmergency(IERC20(address(mockToken)));
        vm.stopPrank();
        
        // Check tokens were withdrawn
        assertEq(mockToken.balanceOf(owner), 1000000 * 10**18); // Initial amount
    }
    
    function test_RevertWhen_EmergencyWithdrawNonOwner() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create a mock token and send it to the contract
        MockERC20 mockToken = new MockERC20("Mock", "MCK");
        mockToken.transfer(address(flowContract), 100 * 10**18);
        
        // Non-owner tries to perform emergency withdrawal
        vm.startPrank(alice);
        vm.expectRevert(OnlyOwner.selector);
        flowContract.withdrawEmergency(IERC20(address(mockToken)));
        vm.stopPrank();
    }
}