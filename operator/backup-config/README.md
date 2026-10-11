## 配置备份上传脚本

脚本按模块读取 `/data/<模块>/backup.conf`，在 `/opt/backup`（可由 `BACKUP_DIR` 覆盖）中查找当天或昨天的最新配置备份，并通过 `common/transfer_file.sh` 上传。上传结果通过飞书场景 `backup_config` 通知。

首次配置：

```bash
cd /root/code/deployer/operator/backup-config
cp backup.conf.template backup.conf
cp .env.template .env
chmod 600 .env
```

`backup.conf` 每行一个模块名；`.env` 使用 `WEBDAV_FILE_BASE_URL`、`WEBDAV_FILE_AK`、`WEBDAV_FILE_SK`，并可设置 `BACKUP_DIR`、`DEPLOY_ROOT`、`NOTIFY_FROM`。飞书场景凭据放在 `../feishu-notify/.env`。

### `upload_config_backup.sh`

- 运行位置：服务部署节点
- 运行方式：通常配置为周期性任务执行，也可手动指定模块执行
- 输入参数：`[模块名 ...]`；不传参数时读取 `backup.conf`
- 配置文件：`backup.conf`、`.env`；各模块的 `/data/<模块名>/backup.conf`
- 作用：查找当天或昨天最新的配置备份文件，通过 `common/transfer_file.sh` 上传到 WebDAV，并发送飞书结果通知
- 日志文件：`/opt/logs/upload-config-backup.log`

手动执行：

```bash
bash upload_config_backup.sh                 # 使用 backup.conf 中的全部模块
bash upload_config_backup.sh router project   # 只处理指定模块
```
