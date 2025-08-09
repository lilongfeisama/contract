# Chainlink VRF 随机数生成器使用指南

## 概述

本项目包含两个使用 Chainlink VRF (Verifiable Random Function) 的智能合约：

1. **RandomNumberGenerator** - 基础随机数生成器
2. **AdvancedRandomGenerator** - 高级随机数生成器

## 合约功能

### RandomNumberGenerator (基础版)

**主要功能：**
- 每个用户只能请求一次随机数
- 简单的随机数存储和获取
- 所有者可以重置用户状态

**核心函数：**
```solidity
function requestRandomNumber() external returns (uint256 requestId)
function getRandomNumber(address user) external view returns (uint256)
function hasRequestedRandom(address user) external view returns (bool)
function resetUserRandom(address user) external onlyOwner
```

### AdvancedRandomGenerator (高级版)

**主要功能：**
- 支持请求多个随机数 (1-500个)
- 详细的请求记录和统计
- 多种随机数应用场景
- 支持范围随机数、随机选择、随机布尔值

**核心函数：**
```solidity
function requestRandomWords(uint32 numWords, string memory purpose) external returns (uint256 requestId)
function getRandomNumberInRange(uint256 requestId, uint256 min, uint256 max) external view returns (uint256)
function getRandomChoice(uint256 requestId, uint256 numOptions) external view returns (uint256)
function getRandomBool(uint256 requestId) external view returns (bool)
function getStats() external view returns (uint256 totalRequests, uint256 totalFulfilled, uint256 successRate)
```

## 部署步骤

### 1. 设置环境变量

编辑 `.env` 文件：
```bash
# RPC URLs
RPC_URL_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
RPC_URL_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# Private Keys
PRIVATE_KEY=your_private_key_here

# Chainlink VRF
VRF_SUBSCRIPTION_ID=your_subscription_id_here
```

### 2. 创建 VRF 订阅

#### 在 Sepolia 测试网：
1. 访问 [VRF Subscription Manager](https://vrf.chain.link/sepolia)
2. 连接钱包
3. 创建新订阅
4. 记录订阅 ID

#### 在主网：
1. 访问 [VRF Subscription Manager](https://vrf.chain.link/)
2. 连接钱包
3. 创建新订阅
4. 记录订阅 ID

### 3. 部署合约

```bash
# 编译合约
forge build

# 部署到 Sepolia 测试网
forge script script/DeployVRF.s.sol:DeployVRFScript --rpc-url sepolia --broadcast --verify

# 部署到主网
forge script script/DeployVRF.s.sol:DeployVRFScript --rpc-url mainnet --broadcast --verify
```

## 使用示例

### 基础随机数生成器

```solidity
// 1. 请求随机数
uint256 requestId = randomGenerator.requestRandomNumber();

// 2. 等待 VRF 回调完成 (通常需要几分钟)

// 3. 获取随机数
uint256 randomNumber = randomGenerator.getRandomNumber(msg.sender);

// 4. 检查是否已请求
bool hasRequested = randomGenerator.hasRequestedRandom(msg.sender);
```

### 高级随机数生成器

```solidity
// 1. 请求 5 个随机数
uint256 requestId = advancedGenerator.requestRandomWords(5, "Lottery Game");

// 2. 等待 VRF 回调完成

// 3. 获取请求详情
RandomRequest memory request = advancedGenerator.getRequest(requestId);

// 4. 使用随机数
// 获取 1-100 范围内的随机数
uint256 randomInRange = advancedGenerator.getRandomNumberInRange(requestId, 1, 100);

// 从 10 个选项中随机选择一个
uint256 choice = advancedGenerator.getRandomChoice(requestId, 10);

// 获取随机布尔值
bool randomBool = advancedGenerator.getRandomBool(requestId);

// 5. 查看统计信息
(uint256 totalRequests, uint256 totalFulfilled, uint256 successRate) = advancedGenerator.getStats();
```

## 网络配置

### Sepolia 测试网
- **VRF Coordinator**: `0x50AE5Ea38517FD5DA3Ea1dA317442C7E85C77A78`
- **Gas Lane**: `0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c`
- **Subscription ID**: 需要手动创建

### Ethereum 主网
- **VRF Coordinator**: `0x271682DEB8C4E0901D1a1550aD2e64D568E69909`
- **Gas Lane**: `0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef`
- **Subscription ID**: 需要手动创建

## 测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-test test_RequestRandomNumber

# 运行测试并显示日志
forge test -vvv
```

## 注意事项

### 1. Gas 费用
- VRF 请求需要支付 LINK 代币作为费用
- 确保订阅账户有足够的 LINK 余额

### 2. 回调延迟
- VRF 回调通常需要 1-3 个区块确认
- 在生产环境中，建议实现超时机制

### 3. 安全性
- 随机数在 `fulfillRandomWords` 回调中生成
- 不要在请求时使用随机数，因为此时还未生成

### 4. 订阅管理
- 定期检查订阅余额
- 监控 VRF 请求的成功率

## 常见问题

### Q: 为什么我的随机数请求没有回调？
A: 检查以下几点：
1. 订阅账户是否有足够的 LINK 余额
2. 合约是否正确实现了 `fulfillRandomWords` 函数
3. 网络连接是否正常

### Q: 如何获取真实的随机数？
A: 随机数在 VRF 节点回调 `fulfillRandomWords` 函数时生成，需要等待回调完成。

### Q: 可以请求多少个随机数？
A: 基础版本每个用户只能请求一个，高级版本可以请求 1-500 个随机数。

### Q: 如何重置用户状态？
A: 只有合约所有者可以调用 `resetUserRandom` 函数重置用户状态。

## 扩展功能

### 1. 添加超时机制
```solidity
mapping(uint256 => uint256) public requestTimeouts;

function requestRandomNumberWithTimeout() external returns (uint256 requestId) {
    requestId = requestRandomNumber();
    requestTimeouts[requestId] = block.timestamp + 10 minutes;
}
```

### 2. 批量重置功能
```solidity
function resetMultipleUsers(address[] memory users) external onlyOwner {
    for (uint i = 0; i < users.length; i++) {
        resetUserRandom(users[i]);
    }
}
```

### 3. 事件监听
```solidity
// 监听随机数请求事件
event RandomNumberRequested(uint256 indexed requestId, address indexed requester);

// 监听随机数接收事件
event RandomNumberReceived(uint256 indexed requestId, address indexed requester, uint256 randomNumber);
``` 