# 项目自动化测试脚本规范

## 目标

本规范用于统一不同技术栈项目的自动化测试入口、测试分层、参数、退出码、报告格式和数据清理要求，使开发者、CI、部署脚本和运维人员能够通过同一个入口确认项目是否能够正常工作。

自动化测试主要回答：

- 核心功能是否按预期工作
- 升级后的新版本是否仍兼容现有配置、数据和依赖
- 服务虽然健康，但真实业务链路是否已经损坏

进程存活、端口监听和依赖连接等基础状态应先按 [HEALTH_CHECK.md](./HEALTH_CHECK.md) 检查。

## 一、统一入口

每个项目必须在项目根目录提供：

```text
scripts/test.sh
```

基本调用方式：

```bash
./scripts/test.sh
./scripts/test.sh --suite smoke
```

要求：

- 脚本必须有可执行权限。
- 无参数时默认执行适合本地开发和 CI 的 `unit` 测试。
- 脚本必须从自身位置定位项目根目录，不依赖调用者当前工作目录。
- `scripts/test.sh` 是统一适配层，可以调用 `go test`、`cargo test`、`pytest`、`npm test`、Maven、Gradle 或项目自带测试二进制。
- 调用者不需要了解项目语言和底层测试框架。
- 用于部署后验证的 `smoke` 测试及其运行依赖必须包含在安装包中，或作为与版本绑定的独立测试包交付。
- 测试包版本必须与被测服务版本兼容，不能默认使用任意最新分支测试旧版本。

推荐目录：

```text
<project>/
├── scripts/
│   ├── health-check.sh
│   └── test.sh
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── smoke/
│   ├── e2e/
│   └── fixtures/
└── test-results/
```

目录可以按语言习惯调整，但统一入口和行为不能改变。

## 二、测试分层

脚本必须支持 `--suite`。项目至少实现 `unit` 和 `smoke`；存在数据库、中间件或服务间协作时应实现 `integration`；具备完整用户流程时建议实现 `e2e`。

### 1. `unit`：单元测试

- 验证函数、类、模块或独立业务规则。
- 默认不访问网络、数据库和真实第三方服务。
- 应快速执行，适合作为无参数默认测试。
- 失败必须阻止代码合并或制品生成。

### 2. `integration`：集成测试

- 验证项目与数据库、缓存、MQ、对象存储或内部服务的集成。
- 可以使用测试容器、临时数据库或隔离的测试实例。
- 必须明确所需依赖和初始化方式。
- 测试数据必须使用独立命名空间并在测试后清理。

### 3. `smoke`：冒烟测试

- 用最少且最关键的用例确认部署后的系统能够正常工作。
- 设计目标是稳定、快速、低副作用，通常应在数分钟内完成。
- 必须先确认健康检查通过，再测试至少一条核心业务路径。
- 是升级后恢复流量前的默认功能验证套件。
- 不追求覆盖所有边界条件，只覆盖“系统是否基本可用”。

典型检查：

- 读取服务版本或公开信息
- 完成认证或使用专用测试身份
- 创建一条带唯一标识的测试数据
- 查询并校验该数据
- 按需更新或执行一次核心动作
- 删除测试数据并确认清理成功

### 4. `e2e`：端到端测试

- 从真实入口验证完整用户或业务流程。
- 可以跨越多个服务和中间件。
- 执行时间和副作用通常大于 smoke，不应默认在每台生产实例上执行。
- 需要在 staging、专用租户或明确隔离的生产测试空间中运行。

### 5. `all`：全部适用测试

建议顺序：

```text
unit -> integration -> smoke -> e2e
```

项目可以根据环境跳过明确不适用的套件，但必须输出 `SKIP` 原因，不能把“未运行”报告为“通过”。

## 三、测试用例最低要求

每个测试用例必须包含或能够追踪到：

- 稳定、唯一的用例 ID，例如 `SMOKE-AUTH-001`
- 简短名称和测试目的
- 所属套件
- 前置条件
- 输入或测试数据生成方式
- 执行步骤
- 可自动判断的预期结果
- 清理方式
- 负责人或所属模块

推荐命名：

```text
UNIT-<MODULE>-<NUMBER>
INT-<DEPENDENCY>-<NUMBER>
SMOKE-<FLOW>-<NUMBER>
E2E-<FLOW>-<NUMBER>
```

用例不得只判断“命令没有报错”。应校验关键响应字段、状态变化、持久化结果或可观察的业务效果。

## 四、统一命令行参数

所有项目至少支持：

| 参数 | 必选 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `--suite <suite>` | 否 | `unit` | `unit`、`integration`、`smoke`、`e2e` 或 `all` |
| `--timeout <seconds>` | 否 | 项目定义 | 整个测试运行的最大时间 |
| `--format <format>` | 否 | `text` | `text`、`json` 或 `junit` |
| `--output <path>` | 否 | 标准输出 | 报告文件或目录 |
| `--case <id>` | 否 | 全部 | 只执行指定用例，可重复传入 |
| `--fail-fast` | 否 | 关闭 | 首个失败后停止执行 |
| `--keep-data` | 否 | 关闭 | 调试时保留测试数据，生产环境应禁用 |
| `--quiet` | 否 | 关闭 | 减少过程输出 |
| `--help` | 否 | - | 输出用法并成功退出 |

推荐支持：

| 参数 | 说明 |
| --- | --- |
| `--base-url <url>` | 指定被测服务地址 |
| `--config <path>` | 指定测试配置 |
| `--environment <name>` | `local`、`ci`、`test`、`staging` 或 `prod` |
| `--parallel <count>` | 并行数；可能写相同数据的用例不得并行 |
| `--seed <value>` | 固定随机种子以便复现 |
| `--retries <count>` | 仅重试明确标记为可重试的用例 |
| `--verbose` | 输出更多诊断信息 |

未知参数、非法参数或不存在的用例 ID 必须返回退出码 `2`。

## 五、环境与配置

命令行参数优先于环境变量。推荐通用变量：

```text
TEST_SUITE
TEST_BASE_URL
TEST_TIMEOUT
TEST_FORMAT
TEST_OUTPUT
TEST_ENVIRONMENT
TEST_RUN_ID
TEST_SEED
```

敏感信息使用项目名前缀的环境变量或密钥文件，例如：

```text
WALLET_TEST_USERNAME
WALLET_TEST_PASSWORD
WALLET_TEST_TOKEN
```

要求：

- 提供 `.env.test.template` 或等价测试配置模板，但不得提交真实凭据。
- 不得在命令行、报告、截图或日志中泄漏密码、私钥、完整 token 和生产用户数据。
- 生产 smoke 测试必须使用权限最小化的专用测试账号或租户。
- 测试脚本必须明确显示当前目标环境和地址，但敏感部分必须脱敏。
- 当目标看起来是生产环境时，具有破坏性的测试必须拒绝执行，除非项目提供显式且受控的授权机制。

## 六、退出码

| 退出码 | 含义 | 自动化处理建议 |
| --- | --- | --- |
| `0` | 所有实际执行的必选用例通过 | 继续发布或恢复流量 |
| `1` | 一个或多个测试用例失败 | 停止发布并评估回滚 |
| `2` | 参数、配置或测试选择错误 | 修正调用方式 |
| `3` | 测试框架或环境异常，测试未能正确执行 | 修复环境或脚本后重试 |
| `4` | 整体测试超时 | 检查服务、依赖和超时配置 |
| `5` | 测试数据清理失败 | 隔离残留数据并人工处理 |

“没有找到任何用例”不能返回成功，应返回 `2` 或 `3` 并明确原因。

## 七、输出和测试报告

### 文本输出

```text
[PASS] SMOKE-INFO-001 read service information (42 ms)
[PASS] SMOKE-ORDER-001 create and query test order (315 ms)
[SKIP] SMOKE-NOTIFY-001 notification provider is disabled
RESULT status=pass suite=smoke passed=2 failed=0 skipped=1 duration_ms=357
```

状态统一使用：

- `PASS`
- `FAIL`
- `SKIP`

测试用例不建议使用 `WARN` 代替失败。如果行为不满足预期，应失败；如果用例不适用，应跳过并说明原因。

### JSON 输出

`--format json` 必须输出一个合法 JSON 对象：

```json
{
  "schema_version": "1.0",
  "type": "automated_test",
  "project": "example-service",
  "version": "v1.2.3",
  "environment": "staging",
  "suite": "smoke",
  "run_id": "deploy-20260726-001",
  "status": "pass",
  "started_at": "2026-07-26T10:05:00Z",
  "duration_ms": 357,
  "summary": {
    "total": 3,
    "passed": 2,
    "failed": 0,
    "skipped": 1
  },
  "cases": [
    {
      "id": "SMOKE-ORDER-001",
      "name": "create and query test order",
      "status": "pass",
      "duration_ms": 315,
      "message": "test order was created, queried and removed"
    }
  ]
}
```

要求：

- 顶层 `status` 只允许 `pass` 或 `fail`。
- `run_id` 必须能够关联部署记录、版本和测试数据。
- 时间使用 RFC 3339，耗时使用毫秒。
- 失败用例应提供脱敏后的错误摘要；详细堆栈可以写入单独日志。
- JSON 模式下标准输出只包含 JSON，过程日志写入标准错误。
- 用例失败时仍应尽可能生成完整报告。

### JUnit XML

`--format junit` 用于 CI 和测试平台。输出必须是标准 JUnit XML，并至少包含：

- test suite 名称
- 测试数量、失败数量、跳过数量和耗时
- 每个用例的 ID、名称、耗时和失败摘要

推荐报告目录：

```text
test-results/<run-id>/
├── result.json
├── junit.xml
└── test.log
```

`test-results/` 应加入 `.gitignore`，不得提交运行结果和敏感诊断信息。

## 八、测试数据规范

### 唯一标识

每次执行必须生成或接收 `TEST_RUN_ID`。所有测试数据应包含该标识，例如：

```text
test-deploy-20260726-001-order-001
```

这样可以避免并发冲突，并方便定位和清理残留数据。

### 数据隔离

按优先级选择：

1. 独立测试环境或临时容器
2. 独立数据库/schema/bucket/queue
3. 独立测试租户或账号
4. 带唯一前缀且可精确清理的数据

不得依赖测试用例固定执行顺序共享隐式状态。必须共享时，应由显式 setup/teardown 管理。

### 清理

- 默认无论测试通过还是失败都执行清理。
- Shell 脚本应使用 `trap` 或等价机制保证异常退出时也尝试清理。
- 只能删除本次 `run_id` 创建的数据，禁止宽泛匹配或清空共享表、bucket、queue。
- 清理失败返回退出码 `5`，并输出可人工定位的资源标识。
- `--keep-data` 只用于非生产调试，且必须在结果中明确记录。

## 九、稳定性和重试

- 用例必须可重复执行并产生一致结果。
- 不得使用无条件固定长时间 `sleep` 等待异步结果，应在明确超时内轮询可观察状态。
- 默认不自动重试失败用例，以免掩盖真实缺陷。
- 只有网络抖动等明确可恢复场景可以重试，并在报告中记录尝试次数。
- 断言失败、数据错误、权限错误和兼容性错误不得通过重试变成成功。
- 依赖真实时间的测试应允许注入时间或使用合理时间窗口。
- 随机数据必须记录 seed，以便失败后复现。

## 十、安全约束

- `unit` 和 `integration` 不得默认连接生产环境。
- `smoke` 在生产环境必须低风险、最小写入、可完整清理。
- `e2e` 默认不得在生产环境执行。
- 不得调用真实支付、转账、短信、邮件、链上广播、批量删除等高风险能力；必须使用 sandbox、mock 或专用测试通道。
- 不得修改系统配置、执行数据库迁移或重启服务。
- 不得对共享环境运行压力测试、模糊测试或大规模并发测试。
- 测试失败时不得自动“修正”生产数据。

## 十一、升级后 smoke 测试设计

每个项目应选择 3 到 10 个最关键、最稳定的业务用例组成 smoke 套件。至少覆盖：

1. 读取类能力：服务版本、配置摘要或核心资源查询。
2. 认证与授权：专用测试身份能够登录或调用，越权请求被拒绝。
3. 一条核心业务闭环：创建、查询、必要的状态变化和清理。
4. 一个关键外部依赖链路：数据库、缓存、MQ、存储或内部服务。
5. 升级兼容性：旧配置可读取、已有测试数据可查询，必要时验证迁移结果。

项目不具备某一类能力时，应在测试设计文档中说明不适用原因。

## 十二、升级流程接入

推荐运维调用：

```bash
./scripts/health-check.sh \
  --level readiness \
  --retries 12 \
  --interval 5

TEST_RUN_ID="deploy-$(date -u +%Y%m%dT%H%M%SZ)" \
  ./scripts/test.sh \
  --suite smoke \
  --environment prod \
  --timeout 180 \
  --format json \
  --output test-results/smoke.json
```

执行规则：

- 健康检查失败时不执行 smoke 测试。
- smoke 测试失败时不恢复流量，进入重试、回滚或人工判断流程。
- 不建议自动重复整个 smoke 套件；重试前应先确认失败是否属于短暂环境问题。
- 结果必须关联部署批次、制品版本、Git commit、目标环境和执行时间。
- 回滚后应再次执行健康检查和 smoke 测试，不能只确认旧进程启动。

## 十三、语言和框架适配示例

`scripts/test.sh` 可以根据套件调用不同工具，但对外保持相同接口：

```text
Go          -> go test ./...
Rust        -> cargo test --workspace
Python      -> pytest
Node.js     -> npm test
Java/Maven  -> mvn test
Java/Gradle -> ./gradlew test
```

上述命令只是适配示例。项目需要自行处理 `--suite`、`--case`、超时、报告转换和统一退出码，不能把底层框架不稳定的输出直接作为跨项目接口。

## 十四、脚本实现骨架

```sh
#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

SUITE="${TEST_SUITE:-unit}"
FORMAT="${TEST_FORMAT:-text}"
OUTPUT="${TEST_OUTPUT:-}"
RUN_ID="${TEST_RUN_ID:-test-$(date -u +%Y%m%dT%H%M%SZ)-$$}"

cleanup() {
  # 只清理带有本次 RUN_ID 的测试资源。
  :
}
trap cleanup EXIT INT TERM

# 1. 解析并校验通用参数。
# 2. 校验目标环境和安全限制。
# 3. 根据 SUITE 调用项目对应的测试框架。
# 4. 收集每个用例的 ID、状态、耗时和错误摘要。
# 5. 执行清理并检查清理结果。
# 6. 输出 text/json/junit 报告并按统一退出码结束。
```

骨架中的空清理逻辑不能直接用于存在写操作的 smoke 或 e2e 测试。项目必须实现真实、精确且安全的数据清理。

## 十五、项目接入清单

- [ ] 提供可执行的 `scripts/test.sh`
- [ ] 无参数执行 `unit` 测试
- [ ] 提供适合升级后运行的 `smoke` 套件
- [ ] 支持统一参数、退出码和报告格式
- [ ] 每个用例具有稳定 ID 和自动断言
- [ ] 测试目标、版本和环境可识别
- [ ] 测试凭据权限最小化且不会进入日志
- [ ] 测试数据带唯一 `run_id`
- [ ] 异常退出时仍能安全清理测试数据
- [ ] 生产环境禁止高风险测试
- [ ] `test-results/` 已加入 `.gitignore`
- [ ] CI、安装包和升级脚本均通过统一入口调用
- [ ] 回滚后的版本也执行 health + smoke 验证

## 十六、验收标准

1. 无参数执行可以运行单元测试并正确返回退出码。
2. `--suite smoke` 能在目标环境完成至少一条核心业务闭环。
3. 用例断言失败时脚本返回 `1`，不会误报成功。
4. 参数错误返回 `2`，框架异常返回 `3`，超时返回 `4`。
5. 用例清单为空时脚本不能返回成功。
6. 文本、JSON 和 JUnit 报告中的通过、失败、跳过数量一致。
7. 同一套 smoke 测试可以连续执行两次，不产生冲突和残留数据。
8. 测试失败或被中断后，清理机制仍会执行。
9. 从项目根目录以外调用脚本仍可正常工作。
10. 安装包中的 smoke 测试无需开发目录的未提交文件或本地缓存。
11. 报告可以关联项目版本、部署批次和目标环境。
12. 生产环境执行时不会触发真实高风险业务动作。
