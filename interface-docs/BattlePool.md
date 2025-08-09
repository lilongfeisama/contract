# BattlePool 合约接口文档

本文档列出 `BattlePool` 合约对外公开的方法与事件，便于其他合约或前端进行交互。

## 查询类（View）函数

| 函数 | 说明 | 参数 | 返回值 |
| ---- | ---- | ---- | ------ |
| `getPlayers(uint256 matchId)` | 获取某场对战的所有玩家地址 | `matchId` 对战 ID | 玩家地址数组 |
| `getCurrentRound(uint256 matchId)` | 查询当前回合数（起始为 1） | `matchId` | 当前回合 |
| `isFinished(uint256 matchId)` | 对战是否已结束 | `matchId` | `true/false` |
| `getPlayerTotalBet(uint256 matchId, address player)` | 玩家在该局的总下注额 | `matchId`，`player` | 金额 |
| `getRoundBet(uint256 matchId, uint256 round, address player)` | 某玩家在指定回合的下注 | `matchId`，`round`，`player` | 金额 |
| `getFinalScore(uint256 matchId, address player)` | 玩家最终得分（对战结束后） | `matchId`，`player` | 得分 |
| `getTotalPool(uint256 matchId)` | 查询奖池总额 | `matchId` | 金额 |
| `getStoryTokenId(uint256 matchId)` | 获取关联的故事 NFT `tokenId` | `matchId` | `tokenId` |
| `getTotalRounds(uint256 matchId)` | 查询对战总回合数（需对战已结束） | `matchId` | 总回合数 |
| `getWithdrawable(address account)` | 查询指定地址可提余额 | `account` | 金额 |
| `getMyWithdrawable()` | 查询调用者自身可提余额 | 无 | 金额 |

## 管理员相关

| 函数 | 说明 | 参数 | 权限 |
| ---- | ---- | ---- | ---- |
| `addAdmin(address newAdmin)` | 添加管理员 | `newAdmin` 新管理员地址 | 仅超级管理员 |
| `removeAdmin(address adminToRemove)` | 移除管理员 | `adminToRemove` 被移除的管理员地址 | 仅超级管理员 |
| `setStoryNftContract(address newAddress)` | 设置故事 NFT 合约地址 | `newAddress` 合约地址 | 仅超级管理员 |
| `setPlatformFeeBps(uint16 bps)` | 设置平台抽成（基点） | `bps` 抽成基点数 | 仅超级管理员 |
| `setDefaultStoryOwnerFeeBps(uint16 bps)` | 设置默认故事持有者抽成 | `bps` 抽成基点数 | 任一管理员 |
| `setStoryOwnerFeeBpsForToken(uint256 storyTokenId, uint16 bps)` | 设置某故事 NFT 的抽成费率 | `storyTokenId`，`bps` | 故事持有者或任一管理员 |

## 对战流程

| 函数 | 说明 | 参数 | 备注 |
| ---- | ---- | ---- | ---- |
| `createMatch(address[] _players, uint256 _storyTokenId)` | 创建对战并返回其 ID | `_players` 玩家地址数组；`_storyTokenId` 故事 NFT | 仅管理员调用 |
| `bet(uint256 matchId)` | 玩家在当前回合下注/加注（附带 `msg.value`） | `matchId` | 仅对战玩家调用；可重复调用 |
| `advanceToNextRound(uint256 matchId)` | 管理员推进到下一回合 | `matchId` | 仅管理员调用 |
| `endMatch(uint256 matchId, address[] players, uint256[] scores)` | 结束对战并按得分分配奖池 | `matchId` 对战 ID；`players` 玩家数组；`scores` 得分数组 | 仅管理员调用；内部记录奖励后玩家自行提取 |

## 资金提取

| 函数 | 说明 | 参数 |
| ---- | ---- | ---- |
| `withdraw()` | 将调用者的可提余额转出到其地址 | 无 |

## 事件

| 事件 | 触发时机 |
| ---- | ---- |
| `MatchCreated(uint256 matchId, address[] players, uint256 storyTokenId)` | 创建对战时 |
| `AdminAdded(address newAdmin)` / `AdminRemoved(address removedAdmin)` | 管理员增删时 |
| `StoryNftContractUpdated(address previous, address current)` | 更新故事 NFT 合约地址时 |
| `PlatformFeeUpdated(uint16 previous, uint16 current)` / `DefaultStoryOwnerFeeUpdated(uint16 previous, uint16 current)` | 更新费率时 |
| `StoryOwnerFeeForTokenUpdated(uint256 storyTokenId, uint16 previous, uint16 current, address setter)` | 设置故事 NFT 费率时 |
| `FeesDistributed(uint256 matchId, uint256 platformFee, uint256 storyOwnerFee, address storyOwner)` | 对战结算费用时 |
| `BetPlaced(uint256 matchId, uint256 round, address player, uint256 amount, uint256 newTotalPool)` | 玩家下注时 |
| `AdvancedToNextRound(uint256 matchId, uint256 newRound)` | 对战进入下一回合时 |
| `MatchEnded(uint256 matchId, uint256 totalPool, uint256 totalScore, uint256 totalRounds)` | 对战结束时 |
| `Withdrawal(address player, uint256 amount)` | 玩家提取奖励时 |

## 其他
- 合约采用 `nonReentrant` 修饰器防重入。
- 接收函数 `receive() external payable {}` 允许合约接收原生币，但不会计入任何对战。

