#!/usr/bin/env sh

set -eu

RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-stable}"

if command -v curl >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
    sh -s -- -y --profile default --default-toolchain "$RUST_TOOLCHAIN"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- https://sh.rustup.rs |
    sh -s -- -y --profile default --default-toolchain "$RUST_TOOLCHAIN"
else
  echo "错误：安装 rustup 需要 curl 或 wget。" >&2
  exit 1
fi

# 让当前脚本后续命令可以立即使用 cargo 和 rustc。
if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
fi

rustc --version
cargo --version
rustup --version

echo "Rust 安装完成。请重新打开终端，或执行：. \"$HOME/.cargo/env\""
