// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.t.sol";
import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions, ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import {TestToken} from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import {SuperToken} from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/SuperFluidFlow.sol";
import "../src/interfaces/ITradeExecutor.sol";
import "../src/interfaces/IFluidFlowStorage.sol";
import "../src/interfaces/IFluidFlowStorageFactory.sol";
/**
 * @title Mock FluidFlowStorage contract for testing
 */
contract MockFluidFlowStorage is IFluidFlowStorage {
    mapping(address => UserFlow) private _userFlows;
    address private _fundAddress;
    uint256 private _fundClosedTime;
    bool private _isFundClosed;
    uint256 private _fundEndTime;
    mapping(address => bool) private userWithdrawnMap;
    
    function userFlows(address user) external view returns (UserFlow memory) {
        return _userFlows[user];
    }
    
    function fundAddress() external view returns (address) {
        return _fundAddress;
    }
    
    function fundClosedTime() external view returns (uint256) {
        return _fundClosedTime;
    }
    
    function isFundClosed() external view returns (bool) {
        return _isFundClosed;
    }
    
    function fundEndTime() external view returns (uint256) {
        return _fundEndTime;
    }
    
    function initialize(address fundAddress_, uint256 fundEndTime_) external {
        _fundAddress = fundAddress_;
        _fundEndTime = fundEndTime_;
    }
    
    function flowCreated(address _user, int96 _flowRate, ISuperToken _token) external {
        _userFlows[_user] = UserFlow({
            startTimestamp: block.timestamp,
            flowRate: _flowRate,
            totalStreamedAmount: 0,
            userAddress: _user,
            token: _token
        });
    }
    
    function flowUpdated(address _user, int96 _newFlowRate) external {
        UserFlow storage flow = _userFlows[_user];
        uint256 timeElapsed = block.timestamp - flow.startTimestamp;
        uint256 amountStreamed = uint256(int256(flow.flowRate)) * timeElapsed;
        flow.totalStreamedAmount += amountStreamed;
        flow.flowRate = _newFlowRate;
        flow.startTimestamp = block.timestamp;
    }
    
    function flowDeleted(address _user) external returns (uint256) {
        UserFlow storage flow = _userFlows[_user];
        uint256 timeElapsed = block.timestamp - flow.startTimestamp;
        uint256 amountStreamed = uint256(int256(flow.flowRate)) * timeElapsed;
        flow.totalStreamedAmount += amountStreamed;
        flow.flowRate = 0;
        return 0; // No excess amount for testing
    }
    
    function setFundClosedTime(uint256 _time) external {
        _fundClosedTime = _time;
        _isFundClosed = true;
    }
    
    function getTotalStreamed(address _user) external view returns (uint256) {
        UserFlow memory flow = _userFlows[_user];
        if (flow.startTimestamp == 0) {
            return 0;
        }
        if (flow.flowRate == 0) {
            return flow.totalStreamedAmount;
        }
        uint256 timeElapsed = block.timestamp - flow.startTimestamp;
        uint256 currentStreamed = uint256(int256(flow.flowRate)) * timeElapsed;
        return flow.totalStreamedAmount + currentStreamed;
    }
    
    function isUserStreamActive(address userAddress) external view returns (bool) {
        return _userFlows[userAddress].flowRate != 0;
    }
    
    function isUserWithdrawn(address userAddress) external view returns (bool) {
        return userWithdrawnMap[userAddress];
    }
    
    function userWithdrawn(address userAddress) external {
        userWithdrawnMap[userAddress] = true;
    }
}

/**
 * @title Mock FluidFlowStorageFactory contract for testing
 */
contract MockFluidFlowStorageFactory is IFluidFlowStorageFactory {
    // Mapping from fund address to its storage contract
    mapping(address => address) public fundToStorage;
    address[] public allStorageContracts;
    
    function createStorage(address fundAddress, uint256 _fundEndTime) external returns (address) {
        require(fundAddress != address(0), "Invalid fund address");
        
        // Create new storage contract
        MockFluidFlowStorage newStorage = new MockFluidFlowStorage();
        
        // Initialize storage with fund address
        newStorage.initialize(fundAddress, _fundEndTime);
        
        address storageAddress = address(newStorage);
        
        // Record the storage contract
        allStorageContracts.push(storageAddress);
        fundToStorage[fundAddress] = storageAddress;
        
        return storageAddress;
    }
    
    function getStorageCount() external view returns (uint256) {
        return allStorageContracts.length;
    }
    
    function getStorageForFund(address fundAddress) external view returns (address) {
        return fundToStorage[fundAddress];
    }
}

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

contract SuperFluidFlowTest is Test {
    SuperfluidFrameworkDeployer.Framework private sf;
    using SuperTokenV1Library for ISuperToken;
    
    ISuperToken private acceptedSuperToken;
    SuperFluidFlow private flowContract;
    MockTradeExecutor private tradeExecutor;
    MockFluidFlowStorageFactory private storageFactory;
    IFluidFlowStorage private fundStorage;
    
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
        
        // Create mock storage factory
        storageFactory = new MockFluidFlowStorageFactory();
        
        // Deploy SuperFluidFlow contract
        flowContract = new SuperFluidFlow(sf.host);
    }

    function testInitializeFlow() public {
        vm.startPrank(owner);
        // Create storage for the fund and get its address
        address storageAddress = storageFactory.createStorage(address(flowContract), block.timestamp + FUND_DURATION);
        fundStorage = IFluidFlowStorage(storageAddress);
        
        flowContract.initialize(
            acceptedSuperToken,
            fundManager,
            FUND_DURATION,
            SUBSCRIPTION_DURATION,
            address(this), // factory
            "Fund Token",
            "FUND",
            address(tradeExecutor),
            fundStorage
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
        flowContract.withdraw();
        vm.stopPrank();
        
        // Check Alice received tokens
        assertTrue(acceptedSuperToken.balanceOf(alice) > 0);
        
        // Try to withdraw again (should succeed but give 0 tokens since already withdrawn)
        uint256 balanceBefore = acceptedSuperToken.balanceOf(alice);
        vm.startPrank(alice);
        flowContract.withdraw();
        vm.stopPrank();
        assertEq(acceptedSuperToken.balanceOf(alice), balanceBefore, "Should not receive tokens on second withdrawal");
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

        vm.startPrank(alice);
        acceptedSuperToken.deleteFlow(alice, address(flowContract));
        vm.stopPrank();
        
        // Bob deletes his flow
        vm.startPrank(bob);
        acceptedSuperToken.deleteFlow(bob, address(flowContract));
        vm.stopPrank();
        
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
        flowContract.withdraw();
        vm.stopPrank();
        
        // Bob withdraws his share
        vm.startPrank(bob);
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
        testInitializeFlow();
        
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

        // Check that the contract has no balance left
        assertEq(acceptedSuperToken.balanceOf(address(flowContract)), 0);
    }
    
    function testEdgeCaseWithdrawals() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Test case 1: Single user with 100% of tokens
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Warp time to accumulate tokens
        vm.warp(block.timestamp + 30 days);

        vm.startPrank(alice);
        acceptedSuperToken.deleteFlow(alice, address(flowContract));
        vm.stopPrank();
        
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
        // Create storage for the fund and get its address
        address storageAddress = storageFactory.createStorage(address(flowContract), block.timestamp + FUND_DURATION);
        fundStorage = IFluidFlowStorage(storageAddress);
        
        flowContract.initialize(
            acceptedSuperToken,
            fundManager,
            FUND_DURATION,
            SUBSCRIPTION_DURATION,
            address(this), // factory
            "Fund Token",
            "FUND",
            address(tradeExecutor),
            fundStorage
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
        IERC20 mockToken = new ERC20("Mock", "MCK");
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
        IERC20 mockToken = new ERC20("Mock", "MCK");
        mockToken.transfer(address(flowContract), 100 * 10**18);
        
        // Non-owner tries to perform emergency withdrawal
        vm.startPrank(alice);
        vm.expectRevert(OnlyOwner.selector);
        flowContract.withdrawEmergency(IERC20(address(mockToken)));
        vm.stopPrank();
    }

    function testSingleUserScenario() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Record initial balance
        uint256 aliceInitialBalance = acceptedSuperToken.balanceOf(alice);
        
        // Alice creates a flow to the contract
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Verify flow is created correctly
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), FLOW_RATE);
        
        // Get fund token and verify fund token flow
        ISuperToken fundToken = flowContract.fundToken();
        assertEq(fundToken.getFlowRate(address(flowContract), alice), FLOW_RATE);
        
        // Let time pass to accumulate tokens (30 days)
        vm.warp(block.timestamp + 30 days);
        
        // Record accumulated balances
        uint256 contractBalance = acceptedSuperToken.balanceOf(address(flowContract));
        uint256 aliceFundTokenBalance = fundToken.balanceOf(alice);

        
        // Alice stops her flow
        vm.startPrank(alice);
        acceptedSuperToken.deleteFlow(alice, address(flowContract));
        vm.stopPrank();
        
        assertEq(contractBalance, aliceFundTokenBalance);
        // Verify flows are stopped
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), 0);
        assertEq(fundToken.getFlowRate(address(flowContract), alice), 0);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Alice withdraws her funds
        vm.startPrank(alice);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Verify final state
        uint256 aliceFinalBalance = acceptedSuperToken.balanceOf(alice);
        uint256 contractFinalBalance = acceptedSuperToken.balanceOf(address(flowContract));
        
        // Contract should have very small or no balance left
        assertLt(contractFinalBalance, 100); // Allow for small dust amount
        
        assertEq(aliceInitialBalance, aliceFinalBalance);
    }
    
    function testTotalFundTokensUsed() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow to get tokens into the contract
        testCreateUserFlow();
        
        // Initial totalFundTokensUsed should be 0
        assertEq(flowContract.totalFundTokensUsed(), 0);
        
        // Let time pass to accumulate tokens
        vm.warp(block.timestamp + 5 days);
        
        // Record current contract balance
        uint256 contractBalanceBefore = acceptedSuperToken.balanceOf(address(flowContract));
        
        // Close the fund - this should set totalFundTokensUsed
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Check totalFundTokensUsed was set correctly
        uint256 totalFundTokensUsed = flowContract.totalFundTokensUsed();
        assertTrue(totalFundTokensUsed > 0, "totalFundTokensUsed should be greater than 0");
        
        // Verify the value is reasonable
        ISuperToken fundToken = flowContract.fundToken();
        uint256 expectedTokensUsed = 1_000_000_000 * 1e18 - fundToken.balanceOf(address(flowContract));
        assertEq(totalFundTokensUsed, expectedTokensUsed, "totalFundTokensUsed should match expected value");
    }
    
    function testUserWithdrawnStatus() public {
        // Initialize the flow contract
        testInitializeFlow();
        
        // Create flow to get tokens into the contract
        testCreateUserFlow();
        
        // Let time pass to accumulate tokens
        vm.warp(block.timestamp + 3 days);
        
        // Close the fund
        vm.startPrank(fundManager);
        flowContract.closeFund();
        vm.stopPrank();
        
        // Record initial balance
        uint256 aliceBalanceBefore = acceptedSuperToken.balanceOf(alice);
        
        // Alice withdraws her share
        vm.startPrank(alice);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Check Alice received tokens
        uint256 aliceBalanceAfter = acceptedSuperToken.balanceOf(alice);
        assertTrue(aliceBalanceAfter > aliceBalanceBefore, "Alice should have received tokens");
        
        // Try to withdraw again - should receive no additional tokens
        vm.startPrank(alice);
        flowContract.withdraw();
        vm.stopPrank();
        
        // Balance should remain the same
        uint256 aliceBalanceAfterSecondWithdraw = acceptedSuperToken.balanceOf(alice);
        assertEq(aliceBalanceAfterSecondWithdraw, aliceBalanceAfter, "No additional tokens should be received on second withdrawal");
    }
    
    function testFlowDeletedAfterFundEnd() public {
        // Initialize the flow contract with a short duration
        vm.startPrank(owner);
        // Create storage for the fund and get its address
        address storageAddress = storageFactory.createStorage(address(flowContract), block.timestamp + 3 days);
        IFluidFlowStorage shortFundStorage = IFluidFlowStorage(storageAddress);
        
        flowContract.initialize(
            acceptedSuperToken,
            fundManager,
            3 days, // Short fund duration
            1 days,  // Short subscription duration
            address(this), // factory
            "Fund Token",
            "FUND",
            address(tradeExecutor),
            shortFundStorage
        );
        vm.stopPrank();
        
        // Create user flows
        vm.startPrank(alice);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        acceptedSuperToken.createFlow(address(flowContract), FLOW_RATE);
        vm.stopPrank();
        
        // Verify flows are created
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), FLOW_RATE);
        assertEq(acceptedSuperToken.getFlowRate(bob, address(flowContract)), FLOW_RATE);
        
        // Warp past fund end time
        vm.warp(block.timestamp + 4 days);
        
        // Delete flow for alice - should properly handle fund end condition
        vm.startPrank(alice);
        acceptedSuperToken.deleteFlow(alice, address(flowContract));
        vm.stopPrank();
        
        // Delete flow for bob - should properly handle fund end condition
        vm.startPrank(bob);
        acceptedSuperToken.deleteFlow(bob, address(flowContract));
        vm.stopPrank();
        
        // Verify flows are deleted
        assertEq(acceptedSuperToken.getFlowRate(alice, address(flowContract)), 0);
        assertEq(acceptedSuperToken.getFlowRate(bob, address(flowContract)), 0);
    }
}