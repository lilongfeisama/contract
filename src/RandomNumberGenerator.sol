// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/**
 * @title RandomNumberGenerator
 * @dev 使用 Chainlink VRF 生成可验证的随机数
 */
contract RandomNumberGenerator is VRFConsumerBaseV2Plus {
    // VRF 相关变量
    IVRFCoordinatorV2Plus private immutable i_vrfCoordinator;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // 随机数相关变量
    mapping(uint256 => address) public s_requestIdToSender;
    mapping(address => uint256) public s_randomNumbers;
    mapping(address => bool) public s_hasRequestedRandom;

    // 事件
    event RandomNumberRequested(uint256 indexed requestId, address indexed requester);
    event RandomNumberReceived(uint256 indexed requestId, address indexed requester, uint256 randomNumber);

    // 错误
    error RandomNumberGenerator__AlreadyRequested();
    error RandomNumberGenerator__NoRandomNumberYet();

    /**
     * @dev 构造函数
     * @param vrfCoordinatorV2 VRF 协调器地址
     * @param subscriptionId 订阅 ID
     * @param gasLane gas lane key hash
     * @param callbackGasLimit 回调 gas 限制
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
     * @return requestId 请求 ID
     */
    function requestRandomNumber() external returns (uint256 requestId) {
        if (s_hasRequestedRandom[msg.sender]) {
            revert RandomNumberGenerator__AlreadyRequested();
        }

        s_hasRequestedRandom[msg.sender] = true;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasLane,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        
        requestId = i_vrfCoordinator.requestRandomWords(request);

        s_requestIdToSender[requestId] = msg.sender;

        emit RandomNumberRequested(requestId, msg.sender);
    }

    /**
     * @dev VRF 回调函数，接收随机数
     * @param requestId 请求 ID
     * @param randomWords 随机数数组
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address requester = s_requestIdToSender[requestId];
        uint256 randomNumber = randomWords[0];

        s_randomNumbers[requester] = randomNumber;

        emit RandomNumberReceived(requestId, requester, randomNumber);
    }

    /**
     * @dev 获取用户的随机数
     * @param user 用户地址
     * @return 随机数
     */
    function getRandomNumber(address user) external view returns (uint256) {
        if (!s_hasRequestedRandom[user]) {
            revert RandomNumberGenerator__NoRandomNumberYet();
        }
        return s_randomNumbers[user];
    }

    /**
     * @dev 检查用户是否已请求随机数
     * @param user 用户地址
     * @return 是否已请求
     */
    function hasRequestedRandom(address user) external view returns (bool) {
        return s_hasRequestedRandom[user];
    }

    /**
     * @dev 重置用户的随机数状态（仅所有者可调用）
     * @param user 用户地址
     */
    function resetUserRandom(address user) external onlyOwner {
        s_hasRequestedRandom[user] = false;
        s_randomNumbers[user] = 0;
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