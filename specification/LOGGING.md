# 社区后台服务日志规范

## 目标

本规范用于统一社区后台服务的日志设计，优先解决以下问题：

- 新服务能快速落地统一日志方案
- 机器人或开发者能直接按约定生成基础日志能力
- 排查问题时能快速区分访问日志、业务日志和错误日志
- 日志内容可读、可检索、可追踪，便于后续接入采集平台

其中，`ERROR` 和 `FATAL` 日志还必须满足本文的“错误事件契约”。这是社区产品之间共享的最低接口：监控、根因分析器和值班人员可以只依赖稳定字段判断影响、责任边界和下一步动作，而不需要猜测自由文本。

本规范面向典型后台服务，默认一个服务至少包含以下日志文件：

- `api.log`
- `<service-name>.log`
- `error.log`

如果服务包含特定场景，还应增加以下日志文件：

- 后台管理、权限变更、资金操作、数据导出：增加 `audit.log`
- 大量定时任务、MQ 消费、批处理任务：增加 `job.log`、`worker.log` 或 `consumer.log`

如果没有特殊说明，社区新服务应默认遵守本规范。

本文件是社区产品日志契约的中心版本。其他代码库应在自己的开发/运维文档中引用本文件，并只补充本产品的事件映射、错误码注册表和采集配置；不得复制后长期维护一份分叉标准。若产品确有特殊需求，应先保持最低字段和语义兼容，再通过版本化变更更新本规范。

## 适用范围

适用场景：

- HTTP / RPC 后台服务
- 定时任务调度服务
- 数据处理服务
- 网关、路由、聚合层服务

不适用场景：

- 仅本地运行的一次性调试脚本
- 临时排障时人工添加的短期调试输出

## 设计原则

- 先满足可定位问题，再追求精细化分类
- 日志按职责拆分，不把所有内容混写到一个文件
- 单行日志应能独立表达核心信息
- 优先结构化字段，减少自由文本拼接
- 默认记录时间、级别、服务名、请求链路标识
- 不记录密码、密钥、token、完整银行卡号等敏感信息
- 对机器人友好，字段命名和输出格式尽量稳定

## 最小落地要求

一个新后台服务至少应满足以下要求：

1. 访问日志写入 `api.log`
2. 业务运行日志写入 `<service-name>.log`
3. 错误和异常日志写入 `error.log`
4. 每条日志至少包含时间、级别、服务名、消息
5. 请求相关日志应包含 `trace_id`
6. HTTP 请求日志应包含方法、路径、状态码、耗时、客户端 IP
7. 错误日志应包含错误摘要，必要时包含堆栈
8. 日志按天或按大小轮转，避免单文件无限增长

对于 `ERROR`、`FATAL`，还必须满足下方的结构化错误事件要求。新服务不得只输出 `ERROR: something failed` 作为唯一诊断信息。

## 错误事件契约（ERROR/FATAL）

### 适用范围

本节适用于所有社区产品的生产服务和后台任务，包括 HTTP/RPC、网关、路由、数据库、迁移、消息消费、定时任务、认证、通知和计费流程。承载用户可见失败的 `WARN` 事件也应尽量使用同一事件字段。

### 事件格式与兼容性

首选单行 JSON。尚未使用 JSON logger 的服务可以使用单行 `event key=value`，但字段名称、取值和语义必须与 JSON 版本完全一致。

JSON 示例：

```json
{"time":"2026-10-13T12:00:00.123+08:00","level":"ERROR","service":"gateway","event":"UPSTREAM_RESP","schema_version":1,"operation":"upstream_request","source":"upstream","outcome":"failed","error_code":"upstream_http_error","retryable":true,"http_status":500,"endpoint":"/v1/responses","model":"example-model","trace_id":"trc-opaque","request_id":"req-opaque","msg":"upstream request failed"}
```

key=value 示例：

```text
UPSTREAM_RESP schema_version=1 operation=upstream_request source=upstream outcome=failed error_code=upstream_http_error retryable=true http_status=500 endpoint="/v1/responses" model="example-model" trace_id="trc-opaque" request_id="req-opaque" msg="upstream request failed"
```

格式要求：

1. 每个事件必须单行；JSON 必须是一个完整对象，key=value 的值使用双引号转义。
2. JSON 使用 `event` 字段作为稳定事件名；key=value 的第一个应用层无键字段是稳定事件名，随后必须有 `schema_version`。日志框架可以在它之前添加时间、级别、服务名等可解析的传输前缀。
3. 当前契约版本为整数 `1`。字段新增应保持向后兼容；删除、改名或改变语义必须提升版本并提供迁移说明。
4. 字段名使用小写 `snake_case`。同一含义不得在不同服务中同时使用 `status`/`http_status`、`error`/`error_code` 等多个名称；HTTP 响应码统一为 `http_status`。
5. `msg` 和错误正文只用于人读，分析器不得依赖完整正文才能识别事件。正文应截断并脱敏。

### ERROR/FATAL 最低字段

除通用字段 `time`、`level`、`service`、`msg` 外，所有 `ERROR`/`FATAL` 事件至少包含：

| 字段 | 要求 |
| --- | --- |
| `event` | 稳定事件名；key=value 格式放在首 token |
| `schema_version` | 当前为 `1` |
| `operation` | 正在执行的动作，如 `upstream_request`、`route_select`、`db_migration` |
| `source` | 责任来源，如 `service`、`upstream`、`database`、`dependency`、`client` |
| `outcome` | `failed`、`aborted`、`timeout`、`canceled` 或 `panic` |
| `error_code` | 稳定、可枚举的产品错误码，不能只写 `error` 或异常文本 |
| `retryable` | 布尔值；表示是否允许按服务策略有限退避重试，不代表一定应重试 |

上下文可用时必须记录：`trace_id`、`request_id`、`user_id`、`group_id`、`token_id`、`channel_id`、`model`、`endpoint`、`http_status`、`duration_ms`、`retry_count`、`fallback_count`。没有值的字段可以省略，但不得用真实密钥填充。用户、令牌、渠道、任务等标识必须是内部 opaque ID 或不可逆摘要。

建议的条件字段：

- 上游已返回 HTTP 响应：`upstream_error_code`、`upstream_error_type`、截断后的 `upstream_error_message`、`upstream_request_id`、`http_status`。
- 健康探测：`health_probe=true`、`consecutive_failures`、`user_impact`、`threshold`。
- 任务/消费：`job_name`、`job_id`、`attempt`、`queue` 或 `topic`。
- 数据库迁移：`migration_name`、`migration_version`、`migration_phase`。

### 稳定事件名和错误码

事件名描述发生了什么，错误码描述为什么失败。社区产品优先复用以下错误码；产品可以扩展，但必须在本产品文档中注册其含义、来源、用户影响、可重试性和处理人：

| 类别 | 推荐错误码 |
| --- | --- |
| 路由/能力 | `no_entitlement_channel`、`model_not_published`、`unsupported_channel_endpoint` |
| 上游 | `upstream_http_error`、`upstream_timeout`、`upstream_transport_error`、`invalid_api_key`、`insufficient_quota`、`model_not_found` |
| 数据库/启动 | `db_query_failed`、`db_migration_failed`、`invalid_config` |
| 计费 | `quota_reserve_failed`、`quota_settle_failed`、`billing_consistency_error` |
| 任务 | `task_execution_failed`、`task_recovery_failed` |

建议复用的事件名包括 `UPSTREAM_ERR`（未收到响应）、`UPSTREAM_RESP`（已收到响应）、`ROUTE_DECISION`、`HEALTH_PROBE`、`DB_MIGRATION`、`TASK_FAILURE` 和 `BILLING_FAILURE`。事件名不是错误码注册表；各产品可增加领域事件，但不得用同一个事件名表达互相矛盾的语义。

### 级别与用户影响

| 级别 | 规则 | 典型例子 |
| --- | --- | --- |
| `DEBUG` | 开发诊断，默认不通知生产 | 脱敏后的请求构造细节 |
| `INFO` | 正常生命周期、成功或恢复 | 上游恢复、迁移完成 |
| `WARN` | 单次可预期、已处理，或不代表用户失败 | 单次探测失败、有限重试中的失败、用户请求未发布模型 |
| `ERROR` | 用户请求失败、路由耗尽、持续依赖失败或数据一致性风险 | 无可用渠道、请求返回 5xx、计费落账失败 |
| `FATAL` | 进程无法安全启动或继续运行，通常随后退出 | 数据库迁移失败、关键配置无效 |

健康探测不能全部降为噪音：单次失败可以是 `WARN`；达到连续失败阈值、触发熔断、没有备用路径或已经出现用户请求失败时，必须生成一条聚合 `ERROR`，并记录健康探测字段和用户影响。用户请求未发布或不支持的模型属于能力边界，记录 `WARN` 并返回明确客户端错误；已发布模型却没有任何合格渠道属于 `ERROR`。

### 隐私、基数和正文限制

不得记录密码、Authorization、Cookie、API key、refresh/access token、私钥、证书原文、完整请求体、完整用户输入或完整上游响应。请求/令牌/渠道/用户标识必须脱敏或使用 opaque ID；高基数值不得拼进 `msg`。错误正文和 `body_preview` 必须限制长度，且不能成为聚合指纹的唯一依据。

### 根因分析与通知契约

分析器必须按结构化字段聚合和排序，至少使用：

`event + operation + source + error_code + upstream_error_code + http_status + endpoint + model + health_probe`。

同一请求的 `trace_id` 和 `request_id` 用于关联，不应导致每次请求单独成组。分析结论必须标记：

- `confirmed`：现有字段和证据足以证明直接根因；
- `likely`：证据支持但仍需外部事实确认；
- `unknown`：缺少必要字段或上游证据，并明确列出补证信息。

`unknown` 不是成功闭环，必须在退避时间后重新分析。生产通知应优先展示 `confirmed`/`likely` 的用户影响、处理动作、责任组件和验证方式；`unknown` 作为待补证据汇总，不能伪装成根因。

原始日志采集与生产通知必须解耦：生产告警群默认接收去重、聚合后的根因分析结果，不逐条转发原始 `ERROR`。`FATAL` 或明确的服务级不可用事件可以立即通知，但也必须带稳定事件字段并执行去重、限频；通知内容应包含事件分组、影响范围、证据、建议动作和验证结果。

### 迁移、测试和兼容验收

新代码必须通过统一结构化事件构造器输出错误。旧的自由文本错误只允许列入迁移清单；修改相关代码时应补齐 `operation`、`error_code` 和 `retryable`。推荐迁移顺序：上游请求/路由、健康探测、计费、数据库迁移，再处理异步任务、认证、通知和其他低频错误。

每个迁移必须至少具备：

1. 一个字段断言测试，验证错误事件包含最低字段且 `retryable` 是布尔值；
2. 一个脱敏测试，确认日志不含密钥、完整 token 和请求体；
3. 一个解析兼容测试，确认 JSON 或 key=value 单行能被采集器和分析器解析；
4. 对新增错误码的注册说明和用户影响说明。

CI 应拒绝缺少 `schema_version`、`operation`、`source`、`outcome`、`error_code` 或 `retryable` 的 ERROR/FATAL 示例。服务升级时必须先兼容读取旧版本，再切换写入新版本，避免分析器因滚动发布丢失事件。

## 一、日志文件职责

### 1. `api.log`

用于记录服务对外请求的访问日志，重点回答：

- 谁调用了接口
- 调用了哪个接口
- 返回是否成功
- 总耗时是多少

建议记录内容：

- 请求时间
- 请求方法，例如 `GET`、`POST`
- 请求路径，例如 `/api/v1/orders`
- 路由模板，例如 `/api/v1/orders/:id`
- 状态码
- 请求耗时，单位毫秒
- 客户端 IP
- 用户标识或调用方标识
- `trace_id`
- `request_id`

不建议写入：

- 大段业务处理过程
- 完整请求体
- 完整响应体
- 敏感 header

### 2. `<service-name>.log`

用于记录服务内部的业务运行过程，重点回答：

- 服务现在正在做什么
- 核心业务流执行到了哪里
- 某个业务动作是否成功

建议记录内容：

- 服务启动、停止、配置加载完成
- 关键任务开始、结束、重试、跳过
- 外部依赖调用结果摘要
- 业务状态变化
- 定时任务执行摘要

推荐按“业务动作”写日志，而不是按“代码行”写日志。

例如：

- `order create started`
- `order create succeeded`
- `sync warehouse inventory finished`

### 3. `error.log`

用于记录错误、异常和需要关注的失败事件，重点回答：

- 出了什么错
- 错误影响了哪个请求或任务
- 当前系统是否需要人工介入

建议写入：

- 未捕获异常
- 数据库、缓存、消息队列、第三方服务调用失败
- 参数校验失败中的系统错误部分
- 重试后仍失败的任务
- 可能导致用户感知异常的问题

不建议把所有 `warn` 都写入 `error.log`。只有真正失败、异常、不可忽略的问题才进入该文件。

### 4. `audit.log`

用于记录需要审计和追责的关键操作，重点回答：

- 谁执行了操作
- 操作了什么对象
- 在什么时间执行
- 操作结果是什么

建议用于以下场景：

- 后台管理操作
- 权限变更
- 资金操作
- 数据导出
- 核心配置变更

至少建议包含：

- `time`
- `level`
- `service`
- `operator`
- `action`
- `target`
- `result`
- `trace_id`
- `msg`

### 5. `job.log`

用于记录定时任务和批处理任务，重点回答：

- 哪个任务开始执行
- 执行结果是什么
- 是否发生重试
- 失败原因是什么

建议用于以下场景：

- 定时任务
- 批处理任务
- 长耗时离线任务

至少建议包含：

- `time`
- `level`
- `service`
- `job_name`
- `job_id`
- `attempt`
- `duration_ms`
- `result`
- `msg`

### 6. `worker.log`

用于记录异步 worker 的处理过程，重点回答：

- 哪个 worker 正在处理任务
- 处理的是哪类任务
- 是否处理成功
- 是否发生重试或丢弃

建议用于以下场景：

- 异步任务队列
- 后台 worker 池
- 延迟任务处理

至少建议包含：

- `time`
- `level`
- `service`
- `worker`
- `job_name`
- `job_id`
- `attempt`
- `duration_ms`
- `result`
- `msg`

### 7. `consumer.log`

用于记录消息消费过程，重点回答：

- 消费了哪条消息
- 来自哪个 topic 或 queue
- 消费结果是什么
- 是否发生重试

建议用于以下场景：

- MQ 消费
- 事件订阅
- 流式消费处理

至少建议包含：

- `time`
- `level`
- `service`
- `consumer`
- `topic` 或 `queue`
- `message_id`
- `attempt`
- `duration_ms`
- `result`
- `msg`

## 二、推荐日志级别

社区服务建议统一使用以下级别：

- `DEBUG`：仅开发或临时排障阶段启用，默认可关闭
- `INFO`：正常流程、状态变化、关键动作完成
- `WARN`：有异常迹象，但流程仍可继续
- `ERROR`：当前操作失败，需要关注或处理
- `FATAL`：服务无法继续运行，记录后立即退出

最低要求：

- `api.log` 以 `INFO` 为主，异常请求可记 `WARN` 或 `ERROR`
- `<service-name>.log` 以 `INFO` 和 `WARN` 为主
- `error.log` 只接收 `ERROR` 和 `FATAL`

`ERROR`/`FATAL` 的字段和分级以本文“错误事件契约”为准；本节的级别说明不能被解释为可以省略结构化字段。

## 三、统一字段规范

为了方便机器人生成代码和日志采集平台统一解析，推荐使用稳定字段名。

### 最小公共字段

每条日志至少应包含：

- `time`：日志时间，使用北京时间或 UTC，但同一服务必须统一
- `level`：日志级别
- `service`：服务名
- `msg`：日志摘要

对于 `ERROR`/`FATAL`，上述公共字段之外还必须包含错误事件契约规定的 `event`、`schema_version`、`operation`、`source`、`outcome`、`error_code` 和 `retryable`。普通 `INFO`/`WARN` 可以按场景选用字段，但建议沿用相同命名。

### 请求场景推荐字段

- `trace_id`：链路追踪 ID
- `request_id`：单次请求 ID
- `method`：HTTP 方法
- `path`：请求路径
- `route`：路由模板
- `http_status`：HTTP 状态码（访问日志也建议使用该名称）
- `duration_ms`：请求耗时
- `client_ip`：客户端 IP
- `user_id`：用户 ID，没有则留空或省略

### 任务场景推荐字段

- `job_name`：任务名
- `job_id`：任务实例 ID
- `attempt`：重试次数
- `duration_ms`：执行耗时
- `result`：成功或失败

### 错误场景推荐字段

- `event`：稳定事件名
- `schema_version`：结构化事件契约版本
- `operation`：失败时正在执行的动作
- `source`：责任来源
- `outcome`：失败结果
- `error_code`：稳定错误码
- `retryable`：是否允许有限退避重试
- `error_message`：截断后的错误摘要，仅供人读
- `error_type`：补充性的实现类型，不替代 `error_code`
- `stack`：堆栈信息
- `component`：出错组件，例如 `mysql`、`redis`、`s3`

## 四、时间格式要求

推荐统一使用以下两种格式之一：

- RFC3339，例如 `2026-05-05T14:32:18+08:00`
- 精确到毫秒的本地时间，例如 `2026-05-05 14:32:18.123`

要求：

- 同一服务只能选择一种主格式
- 生产环境推荐带时区
- 多机部署时必须保证时区一致

推荐优先级：

1. `2026-05-05T14:32:18.123+08:00`
2. `2026-05-05 14:32:18.123`

## 五、日志格式建议

### 推荐格式：单行 JSON

适用场景：

- 需要接入 ELK、Loki、OpenSearch、Datadog 等平台
- 需要机器人稳定生成和解析
- 需要多字段检索和聚合分析

示例：

```json
{"time":"2026-05-05T14:32:18.123+08:00","level":"INFO","service":"order-service","trace_id":"4f3d2e1a","request_id":"req-9c21","method":"POST","path":"/api/v1/orders","route":"/api/v1/orders","http_status":200,"duration_ms":38,"client_ip":"10.10.2.8","msg":"request completed"}
```

错误事件必须额外包含错误事件契约规定的稳定 `event` 和最低字段；示例见上文。访问日志中的状态字段应逐步从旧的 `status` 迁移为 `http_status`，采集器在过渡期可以兼容读取两者。

### 兼容格式：Key-Value 单行文本

适用场景：

- 现有服务暂未使用 JSON logger
- 需要先低成本统一格式

示例：

```text
time=2026-05-05T14:32:18.123+08:00 level=INFO service=order-service trace_id=4f3d2e1a request_id=req-9c21 method=POST path=/api/v1/orders route=/api/v1/orders http_status=200 duration_ms=38 client_ip=10.10.2.8 msg="request completed"
```

不推荐多行自由文本作为主格式，因为不利于采集和检索。

## 六、三类日志推荐示例

### 1. `api.log` 示例

```json
{"time":"2026-05-05T14:32:18.123+08:00","level":"INFO","service":"wallet-service","trace_id":"9f2a7c31","request_id":"req-a102","method":"GET","path":"/api/v1/balance","route":"/api/v1/balance","http_status":200,"duration_ms":12,"client_ip":"10.0.0.15","user_id":"10001","msg":"request completed"}
{"time":"2026-05-05T14:33:04.201+08:00","level":"WARN","service":"wallet-service","trace_id":"1db83f44","request_id":"req-a103","method":"POST","path":"/api/v1/transfer","route":"/api/v1/transfer","http_status":429,"duration_ms":4,"client_ip":"10.0.0.16","user_id":"10001","msg":"request rejected by rate limit"}
```

### 2. `<service-name>.log` 示例

```json
{"time":"2026-05-05T14:31:58.002+08:00","level":"INFO","service":"wallet-service","msg":"service started","listen":"0.0.0.0:8080","version":"v1.4.2"}
{"time":"2026-05-05T14:32:40.118+08:00","level":"INFO","service":"wallet-service","trace_id":"9f2a7c31","user_id":"10001","order_id":"ord-20260505-001","msg":"transfer created"}
{"time":"2026-05-05T14:32:41.006+08:00","level":"INFO","service":"wallet-service","job_name":"reconcile-balance","job_id":"job-20260505-01","duration_ms":842,"result":"success","msg":"scheduled job finished"}
```

### 3. `error.log` 示例

```json
{"time":"2026-05-05T14:34:10.445+08:00","level":"ERROR","service":"wallet-service","event":"DB_QUERY","schema_version":1,"operation":"load_balance","source":"database","outcome":"timeout","error_code":"db_query_failed","retryable":true,"component":"mysql","trace_id":"6d18ef20","request_id":"req-a104","duration_ms":3000,"error_message":"query user balance timeout","msg":"database query failed"}
{"time":"2026-05-05T14:34:10.446+08:00","level":"FATAL","service":"wallet-service","event":"DB_MIGRATION","schema_version":1,"operation":"db_migration","source":"database","outcome":"failed","error_code":"db_migration_failed","retryable":false,"migration_name":"202610061200_add_column","migration_version":"202610061200","migration_phase":"apply","error_message":"required column is missing","msg":"database migration failed"}
```

## 七、敏感信息处理

以下内容不得直接写入日志：

- 密码
- Access Token、Refresh Token
- 私钥、密钥、证书原文
- 完整身份证号
- 完整银行卡号
- 完整手机号，除非业务明确允许且已脱敏
- 完整请求体中的隐私字段

建议处理方式：

- 用户标识优先记录内部 ID
- 手机号仅展示前 3 后 4
- 银行卡号仅保留后 4 位
- token 只记录不可逆摘要或内部 opaque ID；不得记录可用于认证的 token 前缀

错误示例：

```text
msg="user login failed" password="123456" token="abcd1234efgh5678"
```

正确示例：

```text
msg="user login failed" user_id="10001" token_id="token-opaque"
```

## 八、轮转与保留建议

最低要求：

- 日志必须轮转
- 生产环境必须限制单文件大小或按天切分
- 必须保留最近一段可排障窗口

建议默认值：

- 按天切分，或单文件达到 `100MB` 后轮转
- 保留 `7` 到 `30` 天
- `error.log` 可保留更久，建议至少 `15` 天
- 压缩历史日志，减少磁盘占用

如果服务部署在容器中，也应明确以下策略之一：

- 输出到标准输出，由平台采集
- 写入挂载目录，由宿主机采集

即使最终走标准输出，也应在逻辑上继续区分访问日志、业务日志和错误日志。

## 九、机器人或开发者的实现清单

社区机器人或开发者在创建一个新服务时，至少应自动完成以下事项：

1. 定义服务名，例如 `wallet-service`
2. 创建日志目录，例如 `logs/`
3. 配置三个输出目标：
   - `logs/api.log`
   - `logs/<service-name>.log`
   - `logs/error.log`
4. 提供统一 logger 初始化入口
5. 为 HTTP 中间件自动注入 `trace_id` 和 `request_id`
6. 为访问日志统一输出 `method`、`path`、`http_status`、`duration_ms`
7. 为错误处理统一写入 `error.log`
8. 默认开启轮转策略
9. 提供本地开发和生产环境两套最小配置
10. 如果存在后台管理、权限、资金、导出场景，补充 `audit.log`
11. 如果存在大量异步任务场景，补充 `job.log`、`worker.log` 或 `consumer.log`

## 十、推荐开发约束

为了让社区项目保持一致，建议遵守以下约束：

- 不直接使用 `fmt.Println`、`print` 或无结构的标准输出替代正式日志
- 不在循环高频路径输出大段 `INFO` 日志
- 不在成功路径打印完整对象
- 错误必须带上下文，不能只写 `something wrong`
- 同一个错误不要在多层重复打印，避免日志风暴

错误写法：

```text
ERROR: fail
```

推荐写法：

```text
DB_QUERY schema_version=1 time=2026-05-05T14:34:10.446+08:00 level=ERROR service=wallet-service trace_id=6d18ef20 request_id=req-a104 operation=load_balance source=database outcome=timeout error_code=db_query_failed retryable=true component=mysql error_message="query user balance timeout" msg="database query failed"
```

## 十一、最小模板

如果机器人需要快速生成一份最小可用日志方案，可直接套用以下约定：

```text
日志目录：
- logs/api.log
- logs/<service-name>.log
- logs/error.log

格式：
- 优先单行 JSON

公共字段：
- time
- level
- service
- msg

请求字段：
- trace_id
- request_id
- method
- path
- route
- status
- duration_ms
- client_ip

错误字段：
- error
- error_type
- stack
- component
```

## 十二、评审检查项

提交新服务或改造旧服务时，评审至少检查：

- 是否区分了 `api.log`、`<service-name>.log`、`error.log`
- 涉及后台管理、权限、资金、导出时，是否增加 `audit.log`
- 涉及大量异步任务时，是否增加 `job.log`、`worker.log` 或 `consumer.log`
- 是否包含统一时间格式和服务名
- 是否具备 `trace_id`
- 是否避免敏感信息泄露
- `ERROR`/`FATAL` 是否包含 `event`、`schema_version`、`operation`、`source`、`outcome`、`error_code` 和 `retryable`
- 错误码是否已登记用户影响、可重试性和责任人
- 是否有字段断言、脱敏和解析兼容测试
- 是否有轮转策略
- 是否给出了至少一条访问日志示例
- 是否给出了至少一条错误日志示例

## 十三、推荐结论

对于社区后台服务，默认推荐方案如下：

- 文件拆分：`api.log`、`<service-name>.log`、`error.log`
- 特定场景补充：`audit.log`、`job.log`、`worker.log`、`consumer.log`
- 主格式：单行 JSON
- 时间格式：RFC3339，精确到毫秒并带时区
- 请求追踪：强制 `trace_id`，建议 `request_id`
- 错误落盘：所有 `ERROR` 和 `FATAL` 进入 `error.log`
- 错误事件：统一 `event`/`schema_version`/`operation`/`source`/`outcome`/`error_code`/`retryable`，根因分析按结构化字段聚合
- 轮转策略：按天或按 `100MB` 轮转，保留至少 `7` 天

如果没有充分理由，不建议偏离以上默认方案。
