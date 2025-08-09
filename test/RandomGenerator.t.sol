// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RandomNumberGenerator} from "../src/RandomNumberGenerator.sol";
import {AdvancedRandomGenerator} from "../src/AdvancedRandomGenerator.sol";

contract RandomGeneratorTest is Test {
    RandomNumberGenerator public randomGenerator;
    AdvancedRandomGenerator public advancedGenerator;
    
    // 测试地址
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    // VRF 配置 (本地测试)
    address public constant VRF_COORDINATOR = address(0x5FbDB2315678afecb367f032d93F642f64180aa3);
    uint64 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant GAS_LANE = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 public constant CALLBACK_GAS_LIMIT = 500000;

    function setUp() public {
        // 部署合约
        randomGenerator = new RandomNumberGenerator(
            VRF_COORDINATOR,
            SUBSCRIPTION_ID,
            GAS_LANE,
            CALLBACK_GAS_LIMIT
        );
        
        advancedGenerator = new AdvancedRandomGenerator(
            VRF_COORDINATOR,
            SUBSCRIPTION_ID,
            GAS_LANE,
            CALLBACK_GAS_LIMIT
        );
        
        console.log("RandomNumberGenerator deployed at:", address(randomGenerator));
        console.log("AdvancedRandomGenerator deployed at:", address(advancedGenerator));
    }

    function test_Deployment() public {
        assertEq(randomGenerator.getVrfCoordinator(), VRF_COORDINATOR);
        assertEq(randomGenerator.getSubscriptionId(), SUBSCRIPTION_ID);
        assertEq(randomGenerator.getGasLane(), GAS_LANE);
        assertEq(randomGenerator.getCallbackGasLimit(), CALLBACK_GAS_LIMIT);
        
        assertEq(advancedGenerator.getVrfCoordinator(), VRF_COORDINATOR);
        assertEq(advancedGenerator.getSubscriptionId(), SUBSCRIPTION_ID);
        assertEq(advancedGenerator.getGasLane(), GAS_LANE);
        assertEq(advancedGenerator.getCallbackGasLimit(), CALLBACK_GAS_LIMIT);
    }

    function test_RequestRandomNumber() public {
        vm.prank(user1);
        
        // 请求随机数
        uint256 requestId = randomGenerator.requestRandomNumber();
        console.log("Request ID:", requestId);
        
        // 检查状态
        assertTrue(randomGenerator.hasRequestedRandom(user1));
        assertEq(randomGenerator.s_requestIdToSender(requestId), user1);
    }

    function test_RequestRandomWords() public {
        vm.prank(user1);
        
        // 请求多个随机数
        uint256 requestId = advancedGenerator.requestRandomWords(5, "Testing");
        console.log("Request ID:", requestId);
        
        // 检查请求详情
        AdvancedRandomGenerator.RandomRequest memory request = advancedGenerator.getRequest(requestId);
        assertEq(request.requester, user1);
        assertEq(request.purpose, "Testing");
        assertFalse(request.fulfilled);
    }

    function test_GetUserRequests() public {
        vm.prank(user1);
        uint256 requestId1 = advancedGenerator.requestRandomWords(1, "Test 1");
        
        vm.prank(user1);
        uint256 requestId2 = advancedGenerator.requestRandomWords(2, "Test 2");
        
        uint256[] memory requests = advancedGenerator.getUserRequests(user1);
        assertEq(requests.length, 2);
        assertEq(requests[0], requestId1);
        assertEq(requests[1], requestId2);
        assertEq(advancedGenerator.s_userRequestCount(user1), 2);
    }

    function test_GetStats() public {
        // 初始状态
        (uint256 totalRequests, uint256 totalFulfilled, uint256 successRate) = advancedGenerator.getStats();
        assertEq(totalRequests, 0);
        assertEq(totalFulfilled, 0);
        assertEq(successRate, 0);
        
        // 请求随机数
        vm.prank(user1);
        advancedGenerator.requestRandomWords(1, "Test");
        
        (totalRequests, totalFulfilled, successRate) = advancedGenerator.getStats();
        assertEq(totalRequests, 1);
        assertEq(totalFulfilled, 0);
        assertEq(successRate, 0);
    }

    function test_InvalidNumWords() public {
        vm.prank(user1);
        
        // 测试无效的 numWords
        vm.expectRevert(AdvancedRandomGenerator.AdvancedRandomGenerator__InvalidNumWords.selector);
        advancedGenerator.requestRandomWords(0, "Test");
        
        vm.expectRevert(AdvancedRandomGenerator.AdvancedRandomGenerator__InvalidNumWords.selector);
        advancedGenerator.requestRandomWords(501, "Test");
    }

    function test_AlreadyRequested() public {
        vm.prank(user1);
        randomGenerator.requestRandomNumber();
        
        // 再次请求应该失败
        vm.prank(user1);
        vm.expectRevert(RandomNumberGenerator.RandomNumberGenerator__AlreadyRequested.selector);
        randomGenerator.requestRandomNumber();
    }

    function test_GetRandomNumberNotYet() public {
        vm.prank(user1);
        vm.expectRevert(RandomNumberGenerator.RandomNumberGenerator__NoRandomNumberYet.selector);
        randomGenerator.getRandomNumber(user1);
    }

    function test_ResetUserRandom() public {
        vm.prank(user1);
        randomGenerator.requestRandomNumber();
        assertTrue(randomGenerator.hasRequestedRandom(user1));
        
        // 只有所有者可以重置
        vm.prank(user2);
        vm.expectRevert();
        randomGenerator.resetUserRandom(user1);
        
        // 所有者可以重置
        randomGenerator.resetUserRandom(user1);
        assertFalse(randomGenerator.hasRequestedRandom(user1));
    }

    function test_MultipleUsers() public {
        // User1 请求
        vm.prank(user1);
        uint256 requestId1 = randomGenerator.requestRandomNumber();
        
        // User2 请求
        vm.prank(user2);
        uint256 requestId2 = randomGenerator.requestRandomNumber();
        
        assertTrue(randomGenerator.hasRequestedRandom(user1));
        assertTrue(randomGenerator.hasRequestedRandom(user2));
        assertEq(randomGenerator.s_requestIdToSender(requestId1), user1);
        assertEq(randomGenerator.s_requestIdToSender(requestId2), user2);
    }

    // 注意：这些测试需要在真实的 VRF 环境中运行才能测试 fulfillRandomWords
    // 在本地测试中，我们主要测试合约的逻辑和状态管理
} 