# 启动数据库

## 设置首次启动的初始化命令（可选）

```shell
# 参考 init.db.template 目录里的文件写初始化脚本
mkdir init.db

# 添加要执行的sql语句
vi init.db/01.sql

# 需要说明的是，如果容器之前已经启动过，事后放入的脚本将不会执行，需要手动执行
# 如下命令
docker compose exec postgres psql -U postgres -d postgres -f /docker-entrypoint-initdb.d/01.sql
```

## 配置`.env`文件

```shell
cp .env.template .env
# 然后根据需要编辑 .env 文件，如果只是简单本地测试可以不用修改
```

## 启动容器

```shell

docker compose up -d

# 如果需要重启
docker compose down -v && docker compose up -d

```

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
命令            说明
\l              列出数据库
\c dbname       连接数据库
\dt             列出表
\dt *.*         列出所有 schema 的所有表
\dt app.*       列出所有 app schema 的所有表
\d table        查看表结构
\du             列出用户
\dn             列出 schema
\df             列出函数
\dv             列出视图
\di             列出索引
\x              切换显示模式
\timing         显示执行时间
\i file.sql     执行 SQL 文件
\o file         输出到文件
\q              退出
\?              帮助
```

# 安装插件

```shell
# 1. 登陆数据库
docker compose exec postgres psql -U postgres -d postgres

# 2. 创建数据库
create database test;

# 3. 切换数据库
\c test

# 4. 安装插件, 注意插件是数据库粒度，一定要确认当前所处的数据库
# btree_gist 为标准数据类型（int、text、timestamp等）提供 GiST索引 支持，让这些类型可以使用GiST索引的高级特性。
# 当你需要用排除约束防止数据重叠时，就需要 btree_gist，比如
# -- 示例：会议室预订，防止时间冲突
# CREATE TABLE bookings (
#     room_id int,
#     during tsrange,
#     EXCLUDE USING gist (
#         room_id WITH =,      -- 同一房间
#         during WITH &&       -- 时间段不能重叠
#     )
# );
create extension if not exists btree_gist;
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


