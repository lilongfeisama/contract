// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title StoryNFT
 * @notice 代表“游戏背景/故事”的NFT。管理员可铸造，root admin 可添加管理员。
 * - 铸造时写入 IPFS CID；tokenId 自增
 * - 仅在合约中记录 tokenId -> CID（字符串），前端可自组装 ipfs://CID
 */
contract StoryNFT is ERC721, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 private _nextTokenId;
    mapping(uint256 => string) private _tokenCid; // 原始 CID 存储

    constructor(address rootAdmin) ERC721("StoryNFT", "STORY") {
        address adminToSet = rootAdmin == address(0) ? msg.sender : rootAdmin;
        _grantRole(DEFAULT_ADMIN_ROLE, adminToSet); // root admin
        _grantRole(ADMIN_ROLE, adminToSet);         // 初始也具备铸造权限
        _nextTokenId = 1; // 从 1 开始递增
    }

    // 仅 root admin 可添加新的 admin
    function addAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0), "ZERO_ADDR");
        _grantRole(ADMIN_ROLE, newAdmin);
    }

    // 多重继承需要显式合并 ERC721 与 AccessControl 的 ERC165 支持
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // 铸造并设置 IPFS CID，tokenId 自增
    function mint(address to, string calldata ipfsCid)
        external
        onlyRole(ADMIN_ROLE)
        returns (uint256 tokenId)
    {
        require(to != address(0), "ZERO_ADDR");
        require(bytes(ipfsCid).length > 0, "EMPTY_CID");

        tokenId = _nextTokenId;
        _nextTokenId += 1;
        _safeMint(to, tokenId);
        _tokenCid[tokenId] = ipfsCid;
    }

    // 返回原始 CID（不带 ipfs:// 前缀）
    function getCid(uint256 tokenId) external view returns (string memory) {
        return _tokenCid[tokenId];
    }
}


