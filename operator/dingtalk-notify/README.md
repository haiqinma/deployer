## 钉钉通知脚本

`.env` 中按场景配置 `<场景大写>_WEBHOOK_URL`、`<场景大写>_SECRET`，需要 @ 人时再配置 `<场景大写>_RECEIVER`。当前支持场景：`create_package`、`upgrade_service`、`monitor_service`、`account_billing`。

### `dingtalk_reminder.py`

- 运行位置：代码编译节点或服务部署节点
- 运行方式：通常由构建、升级、监控等 Bash 脚本调用
- 输入参数：`<场景> <消息内容>`，或 `<场景> <是否@接收人> <消息内容>`；是否 @ 使用 `True`/`False`
- 配置文件：`.env`；按场景配置 `<场景大写>_WEBHOOK_URL`、`<场景大写>_SECRET`、`<场景大写>_RECEIVER`
- 作用：对钉钉自定义机器人消息签名并发送文本通知，可按场景 @ 指定接收人
- 日志文件：无独立日志文件；标准输出和错误输出由调用脚本重定向到其 `/opt/logs/*.log`

### `send_custom_robot_group_message.py`

- 运行位置：代码编译节点或服务部署节点
- 运行方式：通常手动执行或由其他 Python/Bash 脚本调用
- 输入参数：`--access_token`、`--secret`、`--msg`；可选 `--userid`、`--at_mobiles`、`--is_at_all`
- 配置文件：无，凭据通过命令行参数传入；不要把参数写入可提交脚本
- 作用：调用钉钉自定义机器人 Webhook 发送文本消息，并支持按用户 ID、手机号或全员 @
- 日志文件：无独立日志文件，使用标准输出记录接口响应
