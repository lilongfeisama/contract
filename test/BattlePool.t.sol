// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {BattlePool} from "../src/BattlePool.sol";
import {StoryNFT} from "../src/StoryNFT.sol";

contract BattlePoolTest is Test {
    BattlePool internal pool;
    StoryNFT internal story;

    address internal admin; // 使用外部地址作为 root admin，避免向本测试合约转账
    address internal storyOwner;
    address internal alice;
    address internal bob;

    uint16 internal constant PLATFORM_FEE_BPS = 500; // 5%
    uint16 internal constant STORY_FEE_BPS = 300;    // 3%

    uint256 internal storyTokenId;

    function setUp() public {
        admin = makeAddr("admin");
        storyOwner = makeAddr("storyOwner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // 给参与者一些初始余额
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(storyOwner, 1 ether);
        vm.deal(admin, 1 ether);

        // 部署 StoryNFT 并铸造一个故事 NFT 给 storyOwner
        story = new StoryNFT(admin);
        // 由 admin 铸造给 storyOwner（需要 ADMIN_ROLE）
        vm.prank(admin);
        storyTokenId = story.mint(storyOwner, "ipfs-cid-1");

        // 部署 BattlePool，并配置费率与故事合约
        pool = new BattlePool(admin);
        vm.startPrank(admin);
        pool.setStoryNftContract(address(story));
        pool.setPlatformFeeBps(PLATFORM_FEE_BPS);            // root admin 接口
        pool.setDefaultStoryOwnerFeeBps(STORY_FEE_BPS);      // admin 接口
        vm.stopPrank();
    }

    function test_EndToEnd_Flow_DistributeAndWithdraw() public {
        // 1) 创建比赛（玩家：alice, bob），关联上述 storyTokenId
        address[] memory players = new address[](2);
        players[0] = alice;
        players[1] = bob;
        vm.prank(admin);
        uint256 matchId = pool.createMatch(players, storyTokenId);

        // 初始回合为 1，未结束
        assertEq(pool.getCurrentRound(matchId), 1);
        assertFalse(pool.isFinished(matchId));

        // 2) 第1回合下注：alice 1 ether, bob 3 ether
        vm.prank(alice);
        pool.bet{value: 1 ether}(matchId);
        vm.prank(bob);
        pool.bet{value: 3 ether}(matchId);

        // 总奖池 = 4 ether
        assertEq(pool.getTotalPool(matchId), 4 ether);
        assertEq(pool.getRoundBet(matchId, 1, alice), 1 ether);
        assertEq(pool.getRoundBet(matchId, 1, bob), 3 ether);

        // 3) 推进到下一回合（不再追加下注，仅测试推进）
        vm.prank(admin);
        pool.advanceToNextRound(matchId);
        assertEq(pool.getCurrentRound(matchId), 2);

        // 4) 结束比赛并分配：比分 30 : 70
        address[] memory endPlayers = new address[](2);
        endPlayers[0] = alice;
        endPlayers[1] = bob;
        uint256[] memory scores = new uint256[](2);
        scores[0] = 30;
        scores[1] = 70;

        vm.prank(admin);
        pool.endMatch(matchId, endPlayers, scores);

        // 比赛应标记为结束
        assertTrue(pool.isFinished(matchId));

        // 根据参数计算期望分配
        // pool = 4 ether
        // 平台费 = 4e18 * 5% = 0.2 ether
        // 故事费 = 4e18 * 3% = 0.12 ether
        // 玩家可分配 = 3.68 ether
        uint256 platformFee = (4 ether * uint256(PLATFORM_FEE_BPS)) / 10000; // 0.2 ether
        uint256 storyFee = (4 ether * uint256(STORY_FEE_BPS)) / 10000;       // 0.12 ether
        uint256 poolForPlayers = 4 ether - platformFee - storyFee;   // 3.68 ether
        uint256 aliceShare = (poolForPlayers * 30) / 100;            // 1.104 ether
        uint256 bobShare = (poolForPlayers * 70) / 100;              // 2.576 ether

        // 5) 验证可提余额
        assertEq(pool.getWithdrawable(admin), platformFee);
        assertEq(pool.getWithdrawable(storyOwner), storyFee);
        assertEq(pool.getWithdrawable(alice), aliceShare);
        assertEq(pool.getWithdrawable(bob), bobShare);

        // 结束后禁止继续下注
        vm.prank(alice);
        vm.expectRevert(bytes("MATCH_FINISHED"));
        pool.bet{value: 1 wei}(matchId);

        // 6) 各方提取并校验余额变化
        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;
        uint256 adminBalBefore = admin.balance;
        uint256 storyOwnerBalBefore = storyOwner.balance;

        vm.prank(alice);
        pool.withdraw();
        vm.prank(bob);
        pool.withdraw();
        vm.prank(admin);
        pool.withdraw();
        vm.prank(storyOwner);
        pool.withdraw();

        assertEq(alice.balance, aliceBalBefore + aliceShare);
        assertEq(bob.balance, bobBalBefore + bobShare);
        assertEq(admin.balance, adminBalBefore + platformFee);
        assertEq(storyOwner.balance, storyOwnerBalBefore + storyFee);

        // 再次提取应失败
        vm.prank(alice);
        vm.expectRevert(bytes("NO_FUNDS"));
        pool.withdraw();
    }
}


