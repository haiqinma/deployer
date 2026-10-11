## 数据库备份上传脚本

首次配置：

```bash
cd /root/code/deployer/operator/backup-database
cp backup.conf.template backup.conf
cp .env.template .env
chmod 600 .env
```

脚本默认从 `/opt/backup` 查找 `<模块>-YYYYMMDD-HHMMSS.sql.gz`，每个模块只上传按文件名排序的最新文件。若本目录没有 `.env`，会回退到 `../common/.env`；WebDAV 变量为 `WEBDAV_FILE_BASE_URL`、`WEBDAV_FILE_AK`、`WEBDAV_FILE_SK`。

### `upload_database_backup.sh`

- 运行位置：服务部署节点
- 运行方式：通常配置为周期性任务执行；也可手动执行上传或下载
- 输入参数：无参数或 `upload` 上传最新备份；`download <本地目录>` 下载远端备份
- 配置文件：`backup.conf`、`.env`；无独立 `.env` 时回退使用 `common/.env`
- 作用：按模块查找最新 PostgreSQL `.sql.gz` 备份并上传到 WebDAV，或将远端备份下载到指定目录，并发送飞书结果通知
- 日志文件：`/opt/logs/upload-database-backup.log`

下载操作要求目标目录已存在，且会下载 WebDAV 目录中的全部文件：

```bash
bash upload_database_backup.sh upload
bash upload_database_backup.sh download /tmp/database-backup
```
