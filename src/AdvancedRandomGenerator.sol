// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/**
 * @title AdvancedRandomGenerator
 * @dev 高级随机数生成器，支持多种随机数应用场景
 */
contract AdvancedRandomGenerator is VRFConsumerBaseV2Plus {
    // VRF 相关变量
    IVRFCoordinatorV2Plus private immutable i_vrfCoordinator;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // 随机数请求结构
    struct RandomRequest {
        address requester;
        uint256 timestamp;
        bool fulfilled;
        uint256[] randomNumbers;
        string purpose; // 用途描述
    }

    // 状态变量
    mapping(uint256 => RandomRequest) public s_requests;
    mapping(address => uint256[]) public s_userRequests;
    mapping(address => uint256) public s_userRequestCount;
    
    // 统计信息
    uint256 public s_totalRequests;
    uint256 public s_totalFulfilled;

    // 事件
    event RandomRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint32 numWords,
        string purpose
    );
    event RandomFulfilled(
        uint256 indexed requestId,
        address indexed requester,
        uint256[] randomNumbers
    );

    // 错误
    error AdvancedRandomGenerator__InvalidNumWords();
    error AdvancedRandomGenerator__RequestNotFound();
    error AdvancedRandomGenerator__RequestNotFulfilled();

    /**
     * @dev 构造函数
     */
    constructor(
        address vrfCoordinatorV2,
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
    }

    /**
     * @dev 请求随机数
     * @param numWords 需要的随机数数量 (1-500)
     * @param purpose 用途描述
     * @return requestId 请求 ID
     */
    function requestRandomWords(uint32 numWords, string memory purpose) 
        external 
        returns (uint256 requestId) 
    {
        if (numWords < 1 || numWords > 500) {
            revert AdvancedRandomGenerator__InvalidNumWords();
        }

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasLane,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        
        requestId = i_vrfCoordinator.requestRandomWords(request);

        s_requests[requestId] = RandomRequest({
            requester: msg.sender,
            timestamp: block.timestamp,
            fulfilled: false,
            randomNumbers: new uint256[](0),
            purpose: purpose
        });

        s_userRequests[msg.sender].push(requestId);
        s_userRequestCount[msg.sender]++;
        s_totalRequests++;

        emit RandomRequested(requestId, msg.sender, numWords, purpose);
    }

    /**
     * @dev VRF 回调函数
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) 
        internal 
        override 
    {
        RandomRequest storage request = s_requests[requestId];
        if (request.requester == address(0)) {
            revert AdvancedRandomGenerator__RequestNotFound();
        }

        request.fulfilled = true;
        request.randomNumbers = randomWords;
        s_totalFulfilled++;

        emit RandomFulfilled(requestId, request.requester, randomWords);
    }

    /**
     * @dev 获取请求详情
     * @param requestId 请求 ID
     * @return 请求详情
     */
    function getRequest(uint256 requestId) 
        external 
        view 
        returns (RandomRequest memory) 
    {
        return s_requests[requestId];
    }

    /**
     * @dev 获取用户的随机数请求列表
     * @param user 用户地址
     * @return 请求 ID 数组
     */
    function getUserRequests(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return s_userRequests[user];
    }

    /**
     * @dev 获取指定范围内的随机数
     * @param requestId 请求 ID
     * @param min 最小值
     * @param max 最大值
     * @return 范围内的随机数
     */
    function getRandomNumberInRange(
        uint256 requestId,
        uint256 min,
        uint256 max
    ) external view returns (uint256) {
        RandomRequest memory request = s_requests[requestId];
        if (!request.fulfilled) {
            revert AdvancedRandomGenerator__RequestNotFulfilled();
        }
        if (request.randomNumbers.length == 0) {
            revert AdvancedRandomGenerator__RequestNotFulfilled();
        }

        uint256 randomNumber = request.randomNumbers[0];
        return min + (randomNumber % (max - min + 1));
    }

    /**
     * @dev 从多个选项中随机选择一个
     * @param requestId 请求 ID
     * @param numOptions 选项数量
     * @return 选中的索引 (0-based)
     */
    function getRandomChoice(uint256 requestId, uint256 numOptions) 
        external 
        view 
        returns (uint256) 
    {
        RandomRequest memory request = s_requests[requestId];
        if (!request.fulfilled) {
            revert AdvancedRandomGenerator__RequestNotFulfilled();
        }
        if (request.randomNumbers.length == 0) {
            revert AdvancedRandomGenerator__RequestNotFulfilled();
        }

        uint256 randomNumber = request.randomNumbers[0];
        return randomNumber % numOptions;
    }

    /**
     * @dev 生成随机布尔值
     * @param requestId 请求 ID
     * @return 随机布尔值
     */
    function getRandomBool(uint256 requestId) 
        external 
        view 
        returns (bool) 
    {
        RandomRequest memory request = s_requests[requestId];
        if (!request.fulfilled) {
            revert AdvancedRandomGenerator__RequestNotFulfilled();
        }
        if (request.randomNumbers.length == 0) {
            revert AdvancedRandomGenerator__RequestNotFulfilled();
        }

        uint256 randomNumber = request.randomNumbers[0];
        return (randomNumber % 2) == 1;
    }

    /**
     * @dev 获取统计信息
     * @return totalRequests 总请求数
     * @return totalFulfilled 已完成请求数
     * @return successRate 成功率
     */
    function getStats() 
        external 
        view 
        returns (
            uint256 totalRequests,
            uint256 totalFulfilled,
            uint256 successRate
        ) 
    {
        totalRequests = s_totalRequests;
        totalFulfilled = s_totalFulfilled;
        successRate = totalRequests > 0 ? (totalFulfilled * 100) / totalRequests : 0;
    }

    // Getter 函数
    function getVrfCoordinator() external view returns (address) {
        return address(i_vrfCoordinator);
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }

    function getGasLane() external view returns (bytes32) {
        return i_gasLane;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }
} 