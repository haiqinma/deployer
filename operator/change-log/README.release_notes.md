# release_notes.sh

`release_notes.sh` 通过 `modules.conf` 批量生成模块发布说明。  
脚本会到固定目录下查找模块仓库，默认按“上一次 tag 比较”，调用 Codex 生成最终中文 Markdown。

## 默认行为

1. 从 `scripts/modules.conf` 读取模块名（每行一个，支持 `#` 注释）。
2. 模块仓库路径：`/home/zb/yeying-community/<模块名>`（脚本内固定）。
3. 自动确定版本范围：
   - 若 `HEAD == 最新tag`，则 `上一个tag..最新tag`
   - 否则 `最新tag..HEAD`
4. 先写临时结果：`/tmp/release_notes_<模块名>.md`
5. 再追加到归档：`/opt/packages/release_notes_<模块名>.md`

## 用法

```bash
./scripts/release_notes.sh
./scripts/release_notes.sh --module router
./scripts/release_notes.sh --help
```

如果你当前就在 `scripts/` 目录，请执行：

```bash
./release_notes.sh
```

## modules.conf 示例

文件：`scripts/modules.conf`

```text
# 每行一个模块
router
gateway
billing
```

## 输出约束

脚本已约束最终汇总 Markdown：

- 固定小节：`新增`、`体验`、`性能`、`安全`
- 中文精炼表述
- 不包含以下信息：
  - 提交总数
  - 变更文件数
  - 代码行数变化
  - 贡献者列表

## 可配置项

当前只保留一个可配置项：

- `RELEASE_NOTES_CODEX_BIN`：Codex 命令名，默认 `codex`

