# GitHub Pull Request 规范

## 目标

统一 Pull Request 的创建、描述、评审和合并要求，提高代码评审效率，降低回归风险。

## 适用范围

本规范适用于开发者从个人 Fork 仓库向社区仓库提交代码变更的场景，默认目标分支为社区仓库的 `main`。

## 提交前检查

发起 Pull Request 前，至少完成以下检查：

- 代码基于最新的 `upstream/main`。
- 变更范围单一，一个 Pull Request 只解决一类问题。
- 本地自测已经完成，必要时补充测试或文档。
- 不包含临时代码、调试日志、敏感信息和无关文件。
- 关键改动已经自行 review 过一遍。

如果项目关联 Issue，Pull Request 描述中应明确关联对应 Issue。

## Pull Request 标题

推荐使用与提交信息一致的格式：

```text
type(scope): summary
```

常见类型：

- `feat`：新功能
- `fix`：缺陷修复
- `docs`：文档变更
- `refactor`：重构优化
- `chore`：工程配置或维护工作
- `test`：测试相关

示例：

```text
fix(postgresql): parse .env safely without sourcing
docs(git): add fork and pull request specification
```

## Pull Request 描述

Pull Request 描述建议使用 Markdown，并至少包含以下信息：

- 变更背景
- 主要改动
- 验证方式
- 风险说明
- 关联 Issue

建议模板：

```markdown
## 背景

说明为什么需要这次改动。

## 改动

- 改动点 1
- 改动点 2

## 验证

- [ ] 本地自测完成
- [ ] 关键流程验证完成

## 风险

- 是否存在兼容性风险
- 是否需要额外回归

## 关联

- Closes #<issue-id>
```

## 创建 Pull Request

推荐从个人功能分支直接向社区仓库 `main` 发起 Pull Request。常见流程如下：

```bash
git checkout main
git pull --rebase upstream main

git checkout -b feat/example-feature

# 开发并提交后
git push origin feat/example-feature
```

随后使用 GitHub Web 页面、`gh` 命令或仓库脚本创建 Pull Request。

如果使用当前仓库提供的辅助脚本，可以在仓库根目录执行：

```bash
./scripts/merge.sh
```

该脚本会检查 `origin`、`upstream`、当前分支状态，并调用 GitHub CLI 创建 Pull Request。

## 评审要求

- Pull Request 发起后，应等待 `maintainer` 或指定评审人 review。
- 收到 review 意见后，应尽快更新代码并在评论中说明处理结果。
- 不要在存在未解决核心问题时强行请求合并。
- 如果修改较大，应主动说明重点阅读位置和潜在风险。

## 合并要求

- 社区仓库的 `main` 分支不直接提交代码，只通过 Pull Request 合并。
- 合并前应确认 CI、必要测试和评审结论符合要求。
- 若项目未特别指定，优先采用 Squash Merge，保持主线提交历史清晰。
- 合并完成后，应及时删除无用的远程开发分支。

## 合并后的收尾操作

Pull Request 合并后，建议执行以下同步和清理操作：

```bash
git checkout main
git pull --rebase upstream main
git push origin main

git branch -d feat/example-feature
git push origin --delete feat/example-feature
```

如果本地分支尚未完全合并，可先确认代码状态，再决定是否删除本地分支。
