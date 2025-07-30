// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Coco} from "../src/Coco-NFT.sol";
import {Counter} from "../src/Counter.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // 从环境变量获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 部署 Coco NFT 合约
        Coco coco = new Coco(tx.origin);
        console.log("Coco NFT deployed at:", address(coco));

        // 部署 Counter 合约
        Counter counter = new Counter();
        console.log("Counter deployed at:", address(counter));

        vm.stopBroadcast();
    }
} 