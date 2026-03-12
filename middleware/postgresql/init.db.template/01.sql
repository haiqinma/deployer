-- 创建业务数据库（示例）
CREATE DATABASE app_db;

-- 创建用户
CREATE USER app_user WITH PASSWORD 'app_password';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;

-- 切换到业务数据库后再安装扩展
\c app_db
CREATE EXTENSION IF NOT EXISTS btree_gist;
-- 如果要安装到其他数据库test_db，需要先切换。查看是否安装，需要先登录数据库，然后执行 \dx
-- \c test_db
-- CREATE EXTENSION IF NOT EXISTS btree_gist;
