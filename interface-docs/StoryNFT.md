# StoryNFT 合约接口文档

本文档列出 `StoryNFT` 合约的外部调用接口与相关事件，供前端或其他合约交互参考。

## 查询类（View）函数

| 函数 | 说明 | 参数 | 返回值 |
| ---- | ---- | ---- | ------ |
| `getCid(uint256 tokenId)` | 查询指定 `tokenId` 对应的原始 IPFS CID（无 `ipfs://` 前缀） | `tokenId` NFT 标识 | CID 字符串 |

## 管理员相关

| 函数 | 说明 | 参数 | 权限 |
| ---- | ---- | ---- | ---- |
| `addAdmin(address newAdmin)` | 添加拥有铸造权限的管理员 | `newAdmin` 新管理员地址 | 仅根管理员 |
| `mint(address to, string ipfsCid)` | 为地址铸造新的故事 NFT 并记录 IPFS CID | `to` 接收者地址；`ipfsCid` 原始 CID | 仅管理员 |

## 事件

| 事件 | 触发时机 |
| ---- | ---- |
| `Transfer(address from, address to, uint256 tokenId)` | ERC721 标准转移事件（包括铸造与销毁） |
| `Approval(address owner, address approved, uint256 tokenId)` | ERC721 单个授权变更时 |
| `ApprovalForAll(address owner, address operator, bool approved)` | ERC721 批量授权变更时 |
| `RoleGranted(bytes32 role, address account, address sender)` | 授予角色（如管理员）时 |
| `RoleRevoked(bytes32 role, address account, address sender)` | 撤销角色时 |

## 其他说明

- `tokenId` 从 1 开始自增。
- 仅存储 CID 字符串，前端可自行拼接成 `ipfs://CID` 形式进行访问。

