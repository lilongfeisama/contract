# Snowtrace 验证命令 (推荐方式)
forge verify-contract 0x2a52f073a84048c0146edc5451461cc5be0413e4 src/RandomNumberGenerator.sol:RandomNumberGenerator --chain fuji

# 或者使用完整的参数方式：
forge verify-contract 0x2a52f073a84048c0146edc5451461cc5be0413e4 src/RandomNumberGenerator.sol:RandomNumberGenerator \
--verifier-url 'https://api-testnet.snowtrace.io/api' \
--etherscan-api-key "verifyContract" \
--num-of-optimizations 200 \
--compiler-version 0.8.27 \
--constructor-args $(cast abi-encode "constructor(address,uint256,bytes32,uint32)" 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE 60723383935446816292472713537016072609029051186870032402443674317069432514128 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887 500000)