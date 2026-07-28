# Rust 安装和常用配置

本文档介绍如何使用官方推荐的 **rustup** 安装和管理 Rust 工具链。rustup 会同时安装 `rustc`、`cargo`、标准库以及常用组件，并支持在多个 Rust 版本之间切换。

## 准备工作

Ubuntu 上建议先安装编译依赖：

```bash
sudo apt update
sudo apt install -y build-essential curl pkg-config libssl-dev
```

macOS 需要安装 Xcode Command Line Tools：

```bash
xcode-select --install
```

## 安装 Rust

进入当前目录后执行：

```bash
chmod +x install.sh
./install.sh
```

脚本默认安装最新的 stable 工具链。也可以通过环境变量指定工具链：

```bash
RUST_TOOLCHAIN=nightly ./install.sh
RUST_TOOLCHAIN=1.88.0 ./install.sh
```

安装完成后，重新打开终端，或在当前终端加载环境变量：

```bash
source "$HOME/.cargo/env"
```

检查安装结果：

```bash
rustc --version
cargo --version
rustup --version
```

## 国内镜像

如果 rustup 下载较慢，可以在执行安装脚本前临时使用 [RsProxy](https://rsproxy.cn/) 镜像：

```bash
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
./install.sh
```

Cargo 下载依赖较慢时，在 `~/.cargo/config.toml` 中配置稀疏索引镜像：

```toml
[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[net]
git-fetch-with-cli = true
```

恢复官方 crates.io 时，删除上面的镜像配置即可。

## 常用 rustup 命令

```bash
# 查看当前工具链和已安装版本
rustup show
rustup toolchain list

# 安装和切换工具链
rustup toolchain install stable
rustup toolchain install nightly
rustup default stable

# 更新所有已安装的工具链
rustup update

# 添加代码格式化、静态检查和源码组件
rustup component add rustfmt clippy rust-src

# 添加交叉编译目标，以 Linux ARM64 为例
rustup target add aarch64-unknown-linux-gnu
```

## 为项目固定 Rust 版本

在项目根目录执行：

```bash
rustup override set stable
```

也可以在项目根目录创建 `rust-toolchain.toml`：

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
```

进入该目录后，rustup 会自动使用指定工具链。

## Cargo 常用命令

```bash
# 创建和运行项目
cargo new hello-rust
cd hello-rust
cargo run

# 检查、测试和发布构建
cargo check
cargo test
cargo build --release

# 格式化代码和运行静态检查
cargo fmt --all
cargo clippy --all-targets --all-features
```

## 卸载 Rust

```bash
rustup self uninstall
```
