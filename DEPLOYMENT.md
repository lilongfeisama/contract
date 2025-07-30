# 部署指南

## 环境变量配置

### 1. 创建 `.env` 文件
在项目根目录创建 `.env` 文件，添加以下内容：

```bash
# RPC URLs
RPC_URL_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
RPC_URL_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
RPC_URL_LOCAL=http://localhost:8545

# Private Keys (注意：不要将真实的私钥提交到版本控制)
PRIVATE_KEY=your_private_key_here

# Etherscan API Key (可选)
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 2. 获取 RPC URL
- **Alchemy**: https://www.alchemy.com/
- **Infura**: https://infura.io/
- **QuickNode**: https://www.quicknode.com/

### 3. 获取私钥
⚠️ **安全警告**: 永远不要将真实的私钥提交到版本控制！

从你的钱包导出私钥：
- **MetaMask**: 账户详情 → 导出私钥
- **其他钱包**: 查看钱包的私钥导出功能

## 部署命令

### 本地测试网部署
```bash
# 启动本地节点
anvil

# 在另一个终端部署
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

### Sepolia 测试网部署
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast --verify
```

### 主网部署
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url mainnet --broadcast --verify
```

## 使用环境变量的部署方式

### 方式 1: 使用 foundry.toml 配置的 RPC
```bash
# 使用 .env 文件中的私钥
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast --verify
```

### 方式 2: 直接在命令行指定
```bash
# 从环境变量读取私钥
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL_SEPOLIA \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## 安全注意事项

1. **私钥安全**:
   - 永远不要将私钥提交到 Git
   - 使用 `.env` 文件存储敏感信息
   - 确保 `.env` 在 `.gitignore` 中

2. **测试网优先**:
   - 先在测试网（如 Sepolia）测试
   - 确认无误后再部署到主网

3. **验证合约**:
   - 使用 `--verify` 参数验证合约
   - 确保合约代码公开透明

## 故障排除

### 常见错误
1. **RPC URL 错误**: 检查 RPC URL 是否正确
2. **私钥格式错误**: 确保私钥是 64 位十六进制字符串
3. **余额不足**: 确保账户有足够的 ETH 支付 gas 费

### 调试命令
```bash
# 检查环境变量
echo $RPC_URL_SEPOLIA
echo $PRIVATE_KEY

# 测试连接
cast block-number --rpc-url sepolia
``` 