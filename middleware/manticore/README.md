# Manticore

一个最小可用的 Manticore Search 本地启动目录。

默认暴露以下端口：

- `9306`：MySQL 协议
- `9308`：HTTP API
- `9312`：binary/cluster 协议

## 启动

先复制环境变量模版：

```bash
cp .env.template .env
```

`docker compose` 会读取当前目录下的 `.env`，端口、镜像版本、容器名和时区都从这里控制。

直接本地启动：

```bash
docker compose up -d
```

查看启动日志：

```bash
docker compose logs -f manticore
```

## 验证

执行仓库内的快速验证脚本：

```bash
chmod +x ./test.sh
./test.sh
```

它会通过 HTTP API 创建一个测试表、写入一条数据并查询结果。

## 常用连接方式

SQL 连接：

```bash
mysql -h 127.0.0.1 -P 9306
```

HTTP 查询：

```bash
curl http://127.0.0.1:9308/cli -d 'SHOW TABLES'
```

停止并清理：

```bash
docker compose down
```

如果你希望连数据一起删除：

```bash
docker compose down -v
rm -rf data
```
