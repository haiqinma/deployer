# PHP 安装和配置

本文档整理在开发机上安装 PHP、Composer，以及常见环境配置的方法。

## MacOS

### 使用 Homebrew 安装 PHP

```bash
brew update
brew install php
```

### 检查版本

```bash
php -v
which php
```

### 配置 PATH

如果终端里没有优先使用 Homebrew 安装的 PHP，可以把下面内容追加到 `~/.zshrc`：

```bash
echo 'export PATH="/opt/homebrew/opt/php/bin:/opt/homebrew/opt/php/sbin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Intel Mac 可以改成：

```bash
echo 'export PATH="/usr/local/opt/php/bin:/usr/local/opt/php/sbin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Ubuntu

### 安装 PHP 和常用扩展

```bash
apt update
apt install -y php php-cli php-common php-mbstring php-xml php-curl php-zip php-mysql
```

### 检查版本

```bash
php -v
which php
```

## 常见配置

### 查找配置文件

```bash
php --ini
```

### 常用配置项

编辑 `php.ini`，按需调整下面几个参数：

```ini
date.timezone = Asia/Shanghai
memory_limit = 512M
upload_max_filesize = 50M
post_max_size = 50M
```

修改后重启对应服务，或者重新打开终端。

### 查看已安装扩展

```bash
php -m
```

## 安装 Composer

### MacOS

```bash
brew install composer
```

### Ubuntu

```bash
apt install -y composer
```

### 检查 Composer

```bash
composer -V
```

## Composer 国内镜像

```bash
composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
```

查看当前配置：

```bash
composer config -g --list
```

恢复官方源：

```bash
composer config -g --unset repos.packagist
```
