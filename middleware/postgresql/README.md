# 设置初始化语句(可选)

当数据库容器启动的时候，自动执行的sql语句

1. 拷贝模版

```shell
cp -rf init.db.template init.db
```

2. 在sql脚本中，添加sql语句

# 连接数据库

```shell
# 使用 docker exec
docker compose exec postgres psql -U postgres -d postgres

# 使用客户端工具
psql -h localhost -p 5432 -U postgres -d postgres
```

# 数据库常用命令

## 速查表

```text
命令		说明
\l		列出数据库
\c dbname	连接数据库
\dt	  	列出表
\d table	查看表结构
\du		列出用户
\dn		列出 schema
\df		列出函数
\dv		列出视图
\di		列出索引
\x		切换显示模式
\timing		显示执行时间
\i file.sql	执行 SQL 文件
\o file		输出到文件
\q		退出
\?		帮助
```

# 备份和恢复

```shell
# 备份
docker compose exec -T postgres pg_dump -U postgres myapp > backup.sql

# 恢复
docker compose exec -T postgres psql -U postgres myapp < backup.sql

# 备份所有数据库
docker compose exec -T postgres pg_dumpall -U postgres > backup_all.sql
```


