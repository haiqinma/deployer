# 项目健康检查脚本规范

## 目标

本规范用于统一项目健康检查脚本的入口、参数、检查层级、退出码和输出格式，使开发、测试、部署与运维系统可以用同一种方式判断服务在安装、启动、升级或回滚后是否正常。

健康检查主要回答两个问题：

- 服务是否存活并能继续运行
- 服务是否已经准备好接收真实请求

健康检查不应代替完整业务测试。需要确认登录、创建、查询、计算、消息处理等核心功能是否真正可用时，应继续执行 [AUTOMATED_TESTING.md](./AUTOMATED_TESTING.md) 规定的自动化测试脚本。

## 适用范围

本规范适用于：

- HTTP、RPC、WebSocket 等在线服务
- Worker、Consumer、定时任务等后台服务
- CLI 工具和本地守护进程
- 单体应用、微服务和包含多个组件的项目
- 物理机、虚拟机、容器和 Kubernetes 环境

不同类型项目可以实现不同的检查项，但对外脚本契约应保持一致。

## 一、统一入口

每个可部署项目必须在项目根目录或安装包内提供：

```text
scripts/health-check.sh
```

基本调用方式：

```bash
./scripts/health-check.sh
./scripts/health-check.sh --level readiness
```

要求：

- 脚本必须有可执行权限。
- 无参数执行时，默认等同于 `--level readiness`。
- 脚本必须能够在安装包解压后的项目目录中独立运行。
- 脚本必须根据自身所在位置计算项目根目录，不能依赖调用者当前工作目录。
- 脚本应使用 `/usr/bin/env sh` 或 `/usr/bin/env bash`，并启用严格错误处理。
- 语言相关逻辑可以由 Shell 脚本调用项目自身的二进制、程序或测试框架实现。
- 正式环境不得要求临时安装新的语言依赖后才能执行检查。

推荐安装包结构：

```text
<project>/
├── scripts/
│   ├── starter.sh
│   ├── health-check.sh
│   └── test.sh
├── config/
└── ...
```

## 二、检查层级

脚本必须支持 `--level` 参数。项目至少实现 `liveness` 和 `readiness`，有外部依赖的项目还应实现 `dependency`。

### 1. `liveness`：存活检查

回答“进程是否仍能运行”。检查应快速、稳定，不访问非必要外部依赖。

可选检查项：

- 主进程存在且不是僵尸进程
- 本地端口正在监听
- HTTP `/health/live` 返回成功
- 主事件循环或 worker 心跳未停止
- 磁盘没有达到会导致服务立即退出的阈值

`liveness` 失败通常意味着服务需要重启或回滚。

### 2. `readiness`：就绪检查

回答“服务是否可以接收请求或任务”。除存活检查外，还应验证服务初始化已经完成。

可选检查项：

- 配置加载完成
- HTTP `/health/ready` 返回成功
- 必需端口可访问
- 数据库连接池已建立
- 必需的迁移或初始化已经完成
- Worker 已完成注册并可接收任务
- 服务不是正在关闭、只读维护或不可服务状态

`readiness` 失败时，流量入口应停止向该实例转发请求，但不一定立即重启实例。

### 3. `dependency`：依赖检查

回答“关键外部依赖是否可用”。只检查当前项目正常工作所必需的依赖。

可选检查项：

- 数据库可建立连接并执行轻量只读查询
- Redis 可执行 `PING`
- MQ 可连接并读取元数据
- 对象存储可访问指定 bucket
- 必需的内部服务或第三方 API 可访问
- DNS、证书有效期和系统时间满足运行要求

依赖检查必须设置超时，不得因为某个依赖无响应而无限阻塞。

### 4. `all`：完整健康检查

按以下顺序执行：

```text
liveness -> readiness -> dependency
```

任何必选检查失败时整体失败。非关键依赖可以返回 `WARN`，但必须在文档中说明降级影响。

## 三、统一命令行参数

所有项目至少支持以下参数：

| 参数 | 必选 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `--level <level>` | 否 | `readiness` | `liveness`、`readiness`、`dependency` 或 `all` |
| `--timeout <seconds>` | 否 | `10` | 单个检查项的最大执行时间 |
| `--retries <count>` | 否 | `0` | 首次失败后的重试次数 |
| `--interval <seconds>` | 否 | `2` | 重试间隔 |
| `--format <format>` | 否 | `text` | `text` 或 `json` |
| `--quiet` | 否 | 关闭 | 不输出普通过程信息，只保留最终结果和错误 |
| `--help` | 否 | - | 输出用法并成功退出 |

推荐支持：

| 参数 | 说明 |
| --- | --- |
| `--config <path>` | 指定配置文件路径 |
| `--base-url <url>` | 覆盖被检查服务的访问地址 |
| `--component <name>` | 只检查某个组件，可重复传入 |
| `--wait <seconds>` | 在总时限内等待服务从启动中变为就绪 |
| `--verbose` | 输出诊断信息，但仍不得输出密钥和完整 token |

未知参数、缺少参数值或参数值非法时，脚本必须输出明确错误并以退出码 `2` 结束。

## 四、环境变量

命令行参数优先级高于环境变量。推荐支持以下通用变量：

```text
HEALTH_BASE_URL
HEALTH_TIMEOUT
HEALTH_RETRIES
HEALTH_INTERVAL
HEALTH_FORMAT
HEALTH_CONFIG
```

项目专用变量应以项目名作为前缀，例如：

```text
WALLET_HEALTH_TOKEN
WALLET_HEALTH_DATABASE_URL
```

要求：

- 不得把密码、私钥或 token 作为命令行参数，因为命令行可能被进程列表和审计系统记录。
- 敏感值应通过环境变量、权限受控的配置文件或密钥系统提供。
- 输出中不得打印完整连接串、Authorization header、Cookie 或其他敏感信息。

## 五、退出码

自动化系统必须以退出码作为最终判断依据，不能依赖解析自然语言。

| 退出码 | 含义 | 运维建议 |
| --- | --- | --- |
| `0` | 所有必选检查通过；允许存在明确标记的警告 | 继续部署或恢复流量 |
| `1` | 一个或多个健康检查失败 | 停止升级、重试、回滚或人工处理 |
| `2` | 用法、参数或配置错误，检查没有正确执行 | 修正调用参数或配置 |
| `3` | 检查框架自身异常，例如缺少命令、脚本内部错误 | 修复检查脚本或目标环境 |
| `4` | 整体等待或检查超时 | 检查服务启动时间和依赖状态 |

脚本不得用退出码区分每一个业务检查项；检查项明细应通过输出表达。

## 六、输出规范

### 文本输出

默认文本输出必须适合人工查看。每个检查项输出一行，最终输出汇总。

```text
[PASS] process: service process is running (12 ms)
[PASS] http: GET /health/ready returned 200 (35 ms)
[WARN] disk: available space is below 20% (3 ms)
[PASS] database: read-only query succeeded (18 ms)
RESULT status=pass passed=3 warned=1 failed=0 duration_ms=68
```

状态只使用：

- `PASS`：检查通过
- `WARN`：存在风险或非关键依赖降级，但不阻止服务
- `FAIL`：必选检查失败
- `SKIP`：根据当前配置不适用或明确跳过

### JSON 输出

`--format json` 必须只向标准输出写入一个合法 JSON 对象。日志和诊断信息写入标准错误，避免破坏机器解析。

推荐结构：

```json
{
  "schema_version": "1.0",
  "type": "health_check",
  "project": "example-service",
  "version": "v1.2.3",
  "environment": "prod",
  "level": "all",
  "status": "pass",
  "started_at": "2026-07-26T10:00:00Z",
  "duration_ms": 68,
  "summary": {
    "passed": 3,
    "warned": 1,
    "failed": 0,
    "skipped": 0
  },
  "checks": [
    {
      "name": "http",
      "status": "pass",
      "duration_ms": 35,
      "message": "readiness endpoint returned 200"
    }
  ]
}
```

约束：

- `schema_version` 用于兼容后续格式升级。
- 顶层 `status` 只允许 `pass`、`warn`、`fail`。
- `checks` 顺序应与实际执行顺序一致。
- 时间使用 RFC 3339 格式，耗时统一使用毫秒。
- 字段只允许新增，不应随意删除或改变已有字段语义。
- JSON 模式下即使检查失败也必须尽可能输出完整 JSON，同时返回非零退出码。

## 七、检查行为要求

### 超时和重试

- 每一个网络、进程或外部命令检查都必须有明确超时。
- 重试只用于短暂抖动，不得掩盖持续故障。
- 默认不重试；升级脚本可以通过 `--retries` 或 `--wait` 等待服务启动。
- 每次重试必须重新执行检查，不得复用上一次缓存结果。
- 总执行时间应可估算，不能无限等待。

### 安全与副作用

- 健康检查默认必须只读、幂等且可并发执行。
- 不得重启服务、修改配置、执行迁移、清理数据或自动修复故障。
- 不得创建真实订单、转账、发送通知或执行其他业务写操作。
- 如果验证依赖必须写入数据，应放到自动化测试脚本，而不是健康检查脚本。
- 不得因为某个可选监控工具未安装就把健康服务误判为失败。

### 依赖分类

项目文档必须把依赖标记为：

- `required`：不可用时项目无法正常工作，检查失败记为 `FAIL`
- `optional`：不可用时项目能够降级运行，检查失败记为 `WARN`

不得为了让检查通过，把实际必需的依赖标记为可选。

## 八、HTTP 健康接口建议

提供 HTTP 服务的项目建议实现：

```text
GET /health/live
GET /health/ready
```

建议成功响应：

```json
{
  "status": "ok",
  "service": "example-service",
  "version": "v1.2.3"
}
```

要求：

- 成功使用 HTTP `200`。
- 未就绪或健康失败使用 `503`。
- 健康接口应响应迅速，不执行高成本全表查询。
- 公共健康接口不得泄漏数据库地址、内部拓扑、堆栈或密钥。
- 详细依赖信息可以只允许本机、内网或认证后的运维调用。
- `/health/live` 不应因单个外部依赖短暂失败而失败，否则可能引发无效重启风暴。

## 九、非 HTTP 项目建议

- CLI：执行无副作用的 `version`、`status` 或最小只读命令。
- Worker：检查进程、最近心跳、队列连接和消费暂停状态。
- Consumer：检查进程、broker 连接、订阅状态；积压量可以作为 `WARN` 或按阈值判定失败。
- 定时任务：检查最近一次成功时间是否在预期窗口内。
- 桌面或本地服务：检查进程、IPC/socket 和最小功能响应。

## 十、升级流程接入

推荐升级流程：

```text
升级前 readiness
      ↓
停止流量或进入维护状态
      ↓
部署新版本并启动
      ↓
等待 readiness
      ↓
执行 dependency/all
      ↓
执行自动化 smoke 测试
      ↓
恢复流量并观察
```

示例：

```bash
./scripts/health-check.sh --level readiness --timeout 5
./scripts/starter.sh restart
./scripts/health-check.sh \
  --level readiness \
  --timeout 5 \
  --retries 12 \
  --interval 5
./scripts/health-check.sh --level all --format json > health-result.json
./scripts/test.sh --suite smoke --format json > test-result.json
```

任一步骤返回非零退出码，升级系统应停止后续动作，并根据项目回滚策略决定自动回滚还是请求人工确认。

## 十一、脚本实现骨架

下面的骨架仅展示接口，不包含具体项目检查逻辑：

```sh
#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

LEVEL="${HEALTH_LEVEL:-readiness}"
TIMEOUT="${HEALTH_TIMEOUT:-10}"
RETRIES="${HEALTH_RETRIES:-0}"
INTERVAL="${HEALTH_INTERVAL:-2}"
FORMAT="${HEALTH_FORMAT:-text}"

# 1. 解析并校验参数。
# 2. 根据 LEVEL 执行 liveness/readiness/dependency 检查。
# 3. 为每个外部调用设置 TIMEOUT，并按 RETRIES 重试。
# 4. 收集 PASS/WARN/FAIL/SKIP、耗时和错误摘要。
# 5. 根据 FORMAT 输出文本或单个 JSON 对象。
# 6. 按统一退出码结束。
```

项目不得直接复制骨架后保留空检查；每个 `PASS` 必须来自真实检查结果。

## 十二、项目接入清单

每个项目接入时至少完成：

- [ ] 提供可执行的 `scripts/health-check.sh`
- [ ] 支持 `liveness` 和 `readiness`
- [ ] 有外部依赖时支持 `dependency`
- [ ] 支持统一的必选参数和退出码
- [ ] 支持 `text` 和 `json` 输出
- [ ] 所有外部调用都有超时
- [ ] 默认检查只读、幂等、可重复执行
- [ ] 日志和输出不包含敏感信息
- [ ] 在安装包和干净环境中验证脚本
- [ ] 在部署文档中列明检查项、必需依赖和可选依赖
- [ ] 将健康检查接入升级和回滚流程

## 十三、验收标准

项目健康检查脚本至少应通过以下验收：

1. 服务正常时返回 `0`，文本和 JSON 输出均可解析。
2. 服务停止时，`liveness` 返回非零。
3. 服务启动但未就绪时，`readiness` 返回非零。
4. 必需依赖不可用时，`dependency` 返回非零。
5. 可选依赖不可用时，结果包含 `WARN`，行为与项目文档一致。
6. 非法参数返回 `2`，脚本内部错误返回 `3`。
7. 无响应的依赖能在设定时间内超时退出。
8. 连续和并发执行不会产生业务数据或改变服务状态。
9. 从项目根目录之外调用仍能正确定位项目文件。
10. 安装包内无需开发目录和本地缓存即可运行。
