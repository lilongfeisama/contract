// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Coco} from "../src/Coco-NFT.sol";

contract CocoScript is Script {
    Coco public coco;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        coco = new Coco(tx.origin);

        vm.stopBroadcast();
    }
}

