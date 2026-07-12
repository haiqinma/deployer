# 后端接口规范

## 目标

本规范用于统一社区后端接口的分类、命名、使用和演进方式，方便社区开发者和机器人快速实现一致的接口。

如果没有特殊理由，社区新接口默认遵守本规范。

## 一、接口分类

每个接口有且只有一种分类：

- `public`：公开接口
- `admin`：运营接口
- `internal`：内部接口

如果一个接口同时覆盖多种用途，按以下优先级归类：

1. 只要面向外部用户、第三方伙伴、前端或移动端，归为 `public`
2. 只要面向运营、管理员、客服、风控或租户管理员，归为 `admin`
3. 只面向服务、任务、内部系统调用，归为 `internal`

不要让一个接口同时承担公开、运营、内部三种角色。

## 二、三类接口的适用范围

### `public`

适用场景：

- 前端或移动端调用
- 第三方集成
- 对外开放能力

要求：

- 优先保证稳定性和向下兼容
- 字段命名清晰，避免暴露内部实现细节
- 默认需要完整鉴权、限流和审计能力

示例：

- `GET /api/v1/public/products/{id}`
- `POST /api/v1/public/orders`

### `admin`

适用场景：

- 后台管理
- 权限变更
- 用户治理
- 资金、配置、导出等高风险操作

要求：

- 必须具备严格鉴权和操作审计
- 必须明确操作者身份
- 涉及风险操作时应支持二次确认、审批或幂等控制

示例：

- `POST /api/v1/admin/users/{id}:block`
- `POST /api/v1/admin/configs/{key}:publish`

### `internal`

适用场景：

- 微服务之间调用
- 定时任务和批处理
- 搜索、风控、数据、对账等内部系统调用

要求：

- 可以更贴近内部数据模型
- 允许比 `public` 更快迭代
- 仍应保持明确的版本和兼容策略

示例：

- `POST /api/v1/internal/search:index`
- `POST /api/v1/internal/inventory:reserve`

## 三、接口路径规范

HTTP 路径统一使用以下格式：

```text
/api/v<version>/<category>/<resource>
```

例如：

- `/api/v1/public/products/{id}`
- `/api/v1/admin/users/{id}:block`
- `/api/v1/internal/orders:reconcile`

要求：

1. 路径必须带版本号，例如 `v1`
2. 路径必须显式包含分类：`public`、`admin`、`internal`
3. 资源名使用小写英文，多个单词用中划线或项目既有风格统一处理
4. 资源标识使用路径参数，例如 `{id}`
5. 动作用 `:` 表示，例如 `:block`、`:publish`、`:reconcile`

不要使用：

- `/public/api/v1/...`
- `/api/public/...`
- `/api/v1/doSomething`
- 无版本路径

## 四、方法与语义

优先遵守标准 HTTP 语义：

- `GET`：查询
- `POST`：创建或触发动作
- `PUT`：整体更新
- `PATCH`：部分更新
- `DELETE`：删除

要求：

1. 查询接口不要产生副作用
2. 批量处理、冻结、发布、重建索引等动作型接口，使用 `POST` 加动作后缀
3. 不要用 `GET` 执行写操作

示例：

- `GET /api/v1/public/products/{id}`
- `POST /api/v1/admin/users/{id}:block`
- `PATCH /api/v1/admin/users/{id}`

## 五、请求与响应要求

每个接口至少应明确以下内容：

- 接口分类
- HTTP 方法
- 路径
- 请求参数
- 响应结构
- 错误码
- 鉴权要求

建议：

1. 成功响应结构保持稳定
2. 列表接口明确分页参数和返回格式
3. 错误响应统一，不要每个服务各写一套

推荐统一错误响应至少包含：

- `code`
- `message`
- `request_id`

错误处理默认遵守以下规则：

1. 客户端逻辑只依赖 `code`，不要依赖 `message`
2. `message` 用于人读，`code` 用于程序判断
3. 同一类错误在不同服务中尽量复用同一个 `code`

建议优先使用以下通用错误码：

- `INVALID_ARGUMENT`
- `UNAUTHORIZED`
- `FORBIDDEN`
- `NOT_FOUND`
- `CONFLICT`
- `TOO_MANY_REQUESTS`
- `INTERNAL_ERROR`
- `SERVICE_UNAVAILABLE`
- `TIMEOUT`

业务特有错误可以扩展，例如：

- `ORDER_ALREADY_PAID`
- `BALANCE_NOT_ENOUGH`
- `USER_ALREADY_BLOCKED`

HTTP 状态码和错误码应保持一致，不要所有失败都返回 `200`。

推荐对应关系：

- `400` -> `INVALID_ARGUMENT`
- `401` -> `UNAUTHORIZED`
- `403` -> `FORBIDDEN`
- `404` -> `NOT_FOUND`
- `409` -> `CONFLICT`
- `429` -> `TOO_MANY_REQUESTS`
- `500` -> `INTERNAL_ERROR`
- `503` -> `SERVICE_UNAVAILABLE`

## 六、鉴权与审计

### `public`

- 必须明确鉴权方式，例如 token、session、API key
- 必须定义是否限流

### `admin`

- 必须鉴权
- 必须记录操作者
- 高风险操作必须进入审计日志

### `internal`

- 必须限制调用来源
- 必须有服务身份标识
- 不允许直接暴露给外部客户端

## 七、向下兼容与版本

接口变更时，先判断是否向下兼容。

如果兼容：

- 保持原路径版本不变，例如继续使用 `/api/v1/...`

如果不兼容：

- 升级路径版本，例如 `/api/v2/...`

以下变更通常视为不兼容：

- 删除已有字段
- 修改字段语义
- 修改字段类型
- 修改必填约束
- 修改返回结构导致旧客户端无法解析

以下变更通常可视为兼容：

- 新增可选字段
- 新增不影响旧调用方的返回字段
- 新增可选查询参数

## 八、设计约束

社区开发者在设计接口时，默认遵守以下约束：

1. 先判断接口分类，再开始定义路径
2. 优先复用已有公共接口，不要重复造 `auth`、`health` 一类协议
3. `public` 不暴露内部表结构、内部状态码、内部流程字段
4. `admin` 不与 `public` 复用同一路径
5. `internal` 不直接给前端使用
6. 路径、方法、字段名在一个服务内保持统一风格

## 九、评审检查项

提交新接口或修改接口时，至少检查：

- 是否明确接口分类
- 是否符合 `/api/v1/<category>/...` 路径规则
- 是否使用了合适的 HTTP 方法
- 是否写清楚请求、响应、错误码和鉴权方式
- 错误 `code` 是否稳定、清晰，且可被客户端直接判断
- 是否判断了向下兼容
- 是否错误地把内部接口暴露成公开接口
- 是否遗漏了 `admin` 接口的审计要求

## 十、合理性评审结论

基于原始接口说明，这套规范整体是合理的，但原始版本还不够完整。

原始方案合理的地方：

- 用 `public`、`admin`、`internal` 三分类管理接口，边界清晰
- 明确向下兼容优先，避免随意升级版本

原始方案不足的地方：

- 缺少路径命名和动作命名规则
- 缺少请求、响应、错误码的统一要求
- 缺少鉴权、审计、限流边界
- 缺少对 `admin` 和 `internal` 风险的明确约束
- 缺少对不兼容变更的判断标准

因此，社区可以继续沿用“三类接口 + 兼容优先”这条主线，但需要以本规范补齐落地约束，否则不同服务会很快分叉。
