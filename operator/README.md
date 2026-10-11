# 运维脚本

此目录用于存放社区项目的编译、升级、监控、备份、通知和变更辅助脚本。

升级相关操作从 [`upgrade/README.md`](./upgrade/README.md) 开始；它说明统一入口、
配置、安装包要求、项目升级钩子和回退方式。跨项目的正式规范见
[`../specification/UPGRADE.md`](../specification/UPGRADE.md) 和
[`../specification/PACKAGING.md`](../specification/PACKAGING.md)。

## 目录说明

### `common/`

规划为公共函数、可复用脚本放在该目录下。


### `upgrade/`

提供统一的 `upgrade.sh`、制品编译和传输脚本。项目定制升级逻辑不放在本目录；
纳入统一升级流程的模块必须在安装包中提供 `scripts/upgrade.sh`，由统一入口按标准钩子调用。

### `monitor/`

服务监控的相关脚本统一放在该目录下。

### `change-log/`

版本变更说明相关脚本统一放在该目录下。

### `dingtalk-notify/`

钉钉通知相关的脚本统一放在该目录下。

### `feishu-notify/`

飞书通知相关的脚本统一放在该目录下。


### `backup-config/`

配置文件备份相关的脚本统一放在该目录下。


### `backup-database/`

数据库备份相关的脚本统一放在该目录下。

## 通用约定

- 运行前先阅读对应子目录 README，并从 `.env.template` 或 `*.template` 创建本地配置。
- 凭据只保存在部署节点的未纳入 Git 的配置文件中，不写入脚本、示例或日志。
- 脚本默认将运行日志写入 `/opt/logs`；具体文件名以子目录 README 和脚本实现为准。
- 需要定时运行的脚本应使用 `flock` 避免并发执行，并在部署节点验证权限、路径和通知配置。








