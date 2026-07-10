

# 下载安装包

[访问地址](https://go.dev/doc/install)
[1.24.13](wget https://dl.google.com/go/go1.24.13.linux-amd64.tar.gz)

# 设置代理

## 使用命令永久设置:

go env -w GOPROXY=https://goproxy.cn,direct

## Dockerfile 里面添加：

```text
ENV GOPROXY=https://goproxy.cn,direct
# 关闭模块验证（可选，私有仓库需要）
ENV GOSUMDB=off
```


