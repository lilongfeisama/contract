// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RandomNumberGenerator} from "../src/RandomNumberGenerator.sol";
import {AdvancedRandomGenerator} from "../src/AdvancedRandomGenerator.sol";

contract DeployVRFScript is Script {
    function setUp() public {}

    function run() public {
        // 从环境变量获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 网络配置
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;

        // 根据网络设置不同的参数
        if (block.chainid == 11155111) { // Sepolia
            vrfCoordinator = 0x50AE5eA38517fd5Da3Ea1Da317442c7e85C77a78;
            subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
            gasLane = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
            callbackGasLimit = 500000;
        } else if (block.chainid == 1) { // Ethereum Mainnet
            vrfCoordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
            subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
            gasLane = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;
            callbackGasLimit = 500000;
        } else { // 本地测试网 (Anvil)
            vrfCoordinator = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
            subscriptionId = 1;
            gasLane = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
            callbackGasLimit = 500000;
        }

        // 部署基础随机数生成器
        RandomNumberGenerator randomGenerator = new RandomNumberGenerator(
            vrfCoordinator,
            subscriptionId,
            gasLane,
            callbackGasLimit
        );
        console.log("RandomNumberGenerator deployed at:", address(randomGenerator));

        // 部署高级随机数生成器
        AdvancedRandomGenerator advancedGenerator = new AdvancedRandomGenerator(
            vrfCoordinator,
            subscriptionId,
            gasLane,
            callbackGasLimit
        );
        console.log("AdvancedRandomGenerator deployed at:", address(advancedGenerator));

        vm.stopBroadcast();

        // 输出部署信息
        console.log(unicode"\n=== 部署信息 ===");
        console.log(unicode"网络 ID:", block.chainid);
        console.log("VRF Coordinator:", vrfCoordinator);
        console.log("Subscription ID:", subscriptionId);
        console.logBytes32(gasLane);
        console.log("Callback Gas Limit:", callbackGasLimit);
        console.log(unicode"\n=== 合约地址 ===");
        console.log("RandomNumberGenerator:", address(randomGenerator));
        console.log("AdvancedRandomGenerator:", address(advancedGenerator));
    }
} 