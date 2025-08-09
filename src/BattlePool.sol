// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC721Minimal {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title BattlePool
 * @notice 记录对战、下注与分奖的合约。
 * 功能点：
 *  - 管理员创建对战（传入玩家地址列表与总回合数n），初始为第1回合
 *  - 仅对战玩家可在任意回合对这次对战“下注/加注”（向合约转入原生币）
 *  - 管理员可将对战推进到下一回合，直到第n回合
 *  - 管理员可结束对战并传入每位玩家最终得分，按比例瓜分奖池（本次对战所有下注总额）
 *  - 采用 pull-payment：结算时把玩家应得金额记入其可提余额，玩家自助 withdraw 提取，防重入
 *
 * 注意：
 *  - 结束对战时要求总得分 > 0；若你希望支持总得分=0时按下注额退款，可在结算逻辑中加对应分支
 *  - “下注/加注”函数按当前回合计入明细，同时累计进玩家在本局总下注
 */
contract BattlePool {
    // --- 安全：简易 nonReentrant ---
    uint256 private _status;
    modifier nonReentrant() {
        require(_status != 2, "REENTRANCY");
        _status = 2;
        _;
        _status = 1;
    }

    // --- 访问控制 ---
    address public immutable admin; // 超级管理员（部署/初始化管理员）
    mapping(address => bool) public isAdmin; // 多管理员集合（包含超级管理员）

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "ONLY_ADMIN");
        _;
    }

    modifier onlyRootAdmin() {
        require(msg.sender == admin, "ONLY_ROOT_ADMIN");
        _;
    }

    constructor(address _admin) {
        admin = _admin == address(0) ? msg.sender : _admin;
        isAdmin[admin] = true;
        _status = 1;
    }

    // --- 数据结构 ---
    struct MatchInfo {
        // 基本信息
        uint256 currentRound;     // 从 1 开始
        bool finished;            // 是否已结束
        uint256 totalPool;        // 奖池（本对战所有下注总额）
        uint256 storyTokenId;     // 关联的故事NFT tokenId（决定游戏背景）

        // （移除按场覆盖费率）

        // 玩家信息
        address[] players;
        mapping(address => bool) isPlayer;

        // 下注记录
        mapping(address => uint256) totalBetByPlayer;           // 某玩家在本局的总下注
        mapping(uint256 => mapping(address => uint256)) roundBet; // [round][player] => 该回合下注

        // 结算信息
        uint256 totalScore;                                      // 所有玩家得分之和
        mapping(address => uint256) finalScore;                  // 玩家最终得分
        bool rewardsAssigned;                                    // 是否已将奖励分配到可提余额
    }

    // matchId => MatchInfo
    mapping(uint256 => MatchInfo) private matches;
    uint256 public matchCount;

    // 玩家可提余额（跨所有对战累计）
    mapping(address => uint256) public pendingWithdrawals;

    // 全局：故事NFT合约地址（决定游戏背景）
    address public storyNftContract;

    // 全局费率（基点，1% = 100，100% = 10000）
    uint16 public platformFeeBps; // 平台/管理员抽成比例
    uint16 public defaultStoryOwnerFeeBps; // 故事NFT持有者抽成默认比例
    mapping(uint256 => uint16) public storyOwnerFeeBpsByToken; // story token级别的覆盖费率

    // --- 事件 ---
    event MatchCreated(
        uint256 indexed matchId,
        address[] players,
        uint256 indexed storyTokenId
    );

    event AdminAdded(address indexed newAdmin);
    event AdminRemoved(address indexed removedAdmin);
    event StoryNftContractUpdated(address indexed previous, address indexed current);
    event PlatformFeeUpdated(uint16 previous, uint16 current);
    event DefaultStoryOwnerFeeUpdated(uint16 previous, uint16 current);
    event StoryOwnerFeeForTokenUpdated(uint256 indexed storyTokenId, uint16 previous, uint16 current, address indexed setter);
    event FeesDistributed(uint256 indexed matchId, uint256 platformFee, uint256 storyOwnerFee, address indexed storyOwner);

    event BetPlaced(
        uint256 indexed matchId,
        uint256 indexed round,
        address indexed player,
        uint256 amount,
        uint256 newTotalPool
    );

    event AdvancedToNextRound(
        uint256 indexed matchId,
        uint256 newRound
    );

    event MatchEnded(
        uint256 indexed matchId,
        uint256 totalPool,
        uint256 totalScore,
        uint256 totalRounds
    );

    event Withdrawal(
        address indexed player,
        uint256 amount
    );

    // --- 只读视图帮助方法 ---
    function getPlayers(uint256 matchId) external view returns (address[] memory) {
        return matches[matchId].players;
    }

    function getCurrentRound(uint256 matchId) external view returns (uint256) {
        return matches[matchId].currentRound;
    }

    function isFinished(uint256 matchId) external view returns (bool) {
        return matches[matchId].finished;
    }

    function getPlayerTotalBet(uint256 matchId, address player) external view returns (uint256) {
        return matches[matchId].totalBetByPlayer[player];
    }

    function getRoundBet(uint256 matchId, uint256 round, address player) external view returns (uint256) {
        return matches[matchId].roundBet[round][player];
    }

    function getFinalScore(uint256 matchId, address player) external view returns (uint256) {
        return matches[matchId].finalScore[player];
    }

    function getTotalPool(uint256 matchId) external view returns (uint256) {
        return matches[matchId].totalPool;
    }

    function getStoryTokenId(uint256 matchId) external view returns (uint256) {
        return matches[matchId].storyTokenId;
    }

    function getTotalRounds(uint256 matchId) external view returns (uint256) {
        MatchInfo storage m = matches[matchId];
        require(m.finished, "NOT_FINISHED");
        return m.currentRound;
    }

    // 可提资金查询
    function getWithdrawable(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    function getMyWithdrawable() external view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }

    // --- 管理员管理（仅超级管理员可添加/删除） ---
    function addAdmin(address newAdmin) external onlyRootAdmin {
        require(newAdmin != address(0), "ZERO_ADDR");
        require(!isAdmin[newAdmin], "ALREADY_ADMIN");
        isAdmin[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    function removeAdmin(address adminToRemove) external onlyRootAdmin {
        require(adminToRemove != address(0), "ZERO_ADDR");
        require(isAdmin[adminToRemove], "NOT_ADMIN");
        require(adminToRemove != admin, "CANNOT_REMOVE_ROOT");
        isAdmin[adminToRemove] = false;
        emit AdminRemoved(adminToRemove);
    }

    // --- 故事NFT 关联管理 ---
    function setStoryNftContract(address newAddress) external onlyRootAdmin {
        require(newAddress != address(0), "ZERO_ADDR");
        address previous = storyNftContract;
        storyNftContract = newAddress;
        emit StoryNftContractUpdated(previous, newAddress);
    }

    // --- 费率管理 ---
    function setPlatformFeeBps(uint16 bps) external onlyRootAdmin {
        require(bps <= 1_500, "FEE_GT_15P");
        uint16 prev = platformFeeBps;
        platformFeeBps = bps;
        emit PlatformFeeUpdated(prev, bps);
    }

    function setDefaultStoryOwnerFeeBps(uint16 bps) external onlyAdmin {
        require(bps <= 1_500, "FEE_GT_15P");
        uint16 prev = defaultStoryOwnerFeeBps;
        defaultStoryOwnerFeeBps = bps;
        emit DefaultStoryOwnerFeeUpdated(prev, bps);
    }

    // 故事持有者可为其 token 设置费率；管理员亦可
    function setStoryOwnerFeeBpsForToken(uint256 storyTokenId, uint16 bps) external {
        require(bps <= 1_500, "FEE_GT_15P");
        require(storyNftContract != address(0), "STORY_ADDR_0");

        bool callerIsAdmin = isAdmin[msg.sender];
        bool callerIsStoryOwner = false;
        if (!callerIsAdmin) {
            address owner = IERC721Minimal(storyNftContract).ownerOf(storyTokenId);
            callerIsStoryOwner = (owner == msg.sender);
        }
        require(callerIsAdmin || callerIsStoryOwner, "NO_AUTH");

        uint16 prev = storyOwnerFeeBpsByToken[storyTokenId];
        storyOwnerFeeBpsByToken[storyTokenId] = bps;
        emit StoryOwnerFeeForTokenUpdated(storyTokenId, prev, bps, msg.sender);
    }

    // --- 创建对战 ---
    function createMatch(address[] calldata _players, uint256 _storyTokenId)
    external
    onlyAdmin
    returns (uint256 matchId)
    {
        require(_players.length >= 2, "NEED_2_PLAYERS");

        matchId = ++matchCount;
        MatchInfo storage m = matches[matchId];
        m.currentRound = 1;
        m.finished = false;
        m.storyTokenId = _storyTokenId;

        // 初始化玩家集
        m.players = _players;
        for (uint256 i = 0; i < _players.length; i++) {
            address p = _players[i];
            require(p != address(0), "ZERO_PLAYER");
            require(!m.isPlayer[p], "DUP_PLAYER");
            m.isPlayer[p] = true;
        }

        emit MatchCreated(matchId, _players, _storyTokenId);
    }

    // --- 下注/加注（向合约转入原生币） ---
    function bet(uint256 matchId) external payable nonReentrant {
        MatchInfo storage m = matches[matchId];
        require(!m.finished, "MATCH_FINISHED");
        // currentRound 不再与 totalRounds 绑定；只要未结束即可下注
        require(m.isPlayer[msg.sender], "NOT_PLAYER");
        require(msg.value > 0, "NO_VALUE");

        m.totalPool += msg.value;
        m.totalBetByPlayer[msg.sender] += msg.value;
        m.roundBet[m.currentRound][msg.sender] += msg.value;

        emit BetPlaced(matchId, m.currentRound, msg.sender, msg.value, m.totalPool);
    }

    // --- 管理员推进到下一回合 ---
    function advanceToNextRound(uint256 matchId) external onlyAdmin {
        MatchInfo storage m = matches[matchId];
        require(!m.finished, "MATCH_FINISHED");
        m.currentRound += 1;

        emit AdvancedToNextRound(matchId, m.currentRound);
    }

    /**
     * @notice 结束对战并按得分比例分配奖池至玩家的可提余额
     * @param matchId 对战ID
     * @param players 玩家列表（必须是此对战的玩家集合的子集或等集；通常传全量）
     * @param scores 与 players 一一对应的最终得分
     */
    function endMatch(
        uint256 matchId,
        address[] calldata players,
        uint256[] calldata scores
    ) external onlyAdmin nonReentrant {
        MatchInfo storage m = matches[matchId];
        require(!m.finished, "MATCH_FINISHED");
        require(players.length == scores.length, "LEN_MISMATCH");

        // 统计总分
        uint256 totalScore_;
        for (uint256 i = 0; i < players.length; i++) {
            address p = players[i];
            uint256 s = scores[i];
            require(m.isPlayer[p], "UNKNOWN_PLAYER");
            m.finalScore[p] = s;
            totalScore_ += s;
        }
        require(totalScore_ > 0, "TOTAL_SCORE_ZERO");

        // 费用计算
        uint256 pool = m.totalPool;
        uint256 storyFeeBpsUsed = storyOwnerFeeBpsByToken[m.storyTokenId] > 0
            ? uint256(storyOwnerFeeBpsByToken[m.storyTokenId])
            : uint256(defaultStoryOwnerFeeBps);
        require(uint256(platformFeeBps) + storyFeeBpsUsed <= 10_000, "FEE_TOO_HIGH");
        require(platformFeeBps <= 1_500, "PLATFORM_FEE_GT_15P");
        require(storyFeeBpsUsed <= 1_500, "STORY_FEE_GT_15P");

        uint256 platformFee = (pool * uint256(platformFeeBps)) / 10_000;
        uint256 storyOwnerFee = (pool * storyFeeBpsUsed) / 10_000;
        uint256 poolForPlayers = pool - platformFee - storyOwnerFee;

        // 记入管理员（超级管理员）与故事持有者的可提余额
        if (platformFee > 0) {
            pendingWithdrawals[admin] += platformFee;
        }
        address storyOwnerAddr = address(0);
        if (storyOwnerFee > 0) {
            require(storyNftContract != address(0), "STORY_ADDR_0");
            storyOwnerAddr = IERC721Minimal(storyNftContract).ownerOf(m.storyTokenId);
            pendingWithdrawals[storyOwnerAddr] += storyOwnerFee;
        }
        emit FeesDistributed(matchId, platformFee, storyOwnerFee, storyOwnerAddr);

        m.totalScore = totalScore_;

        // 将剩余奖池按比例分配到 pendingWithdrawals（pull payment）
        uint256 distributed;
        for (uint256 i = 0; i < players.length; i++) {
            address p = players[i];
            uint256 s = scores[i];
            // 分配 = poolForPlayers * s / totalScore
            uint256 share = (poolForPlayers * s) / totalScore_;
            if (share > 0) {
                pendingWithdrawals[p] += share;
                distributed += share;
            }
        }

        // 处理整除误差，把余数给最后一个得分>0的玩家，避免资金卡死
        uint256 remainder = poolForPlayers - distributed;
        if (remainder > 0) {
            // 找到一个得分>0的玩家
            for (uint256 i = players.length; i > 0; i--) {
                address p = players[i - 1];
                if (m.finalScore[p] > 0) {
                    pendingWithdrawals[p] += remainder;
                    break;
                }
            }
        }

        m.finished = true;
        m.rewardsAssigned = true;

        emit MatchEnded(matchId, pool, totalScore_, m.currentRound);
    }

    // --- 玩家提取累计收益 ---
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "NO_FUNDS");
        pendingWithdrawals[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "TRANSFER_FAIL");

        emit Withdrawal(msg.sender, amount);
    }

    // 防止意外直接转账卡死：允许接收，但不记录为任何对战下注
    receive() external payable {}
}
