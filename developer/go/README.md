
# 设置代理

## 使用命令永久设置:

go env -w GOPROXY=https://goproxy.cn,direct

## Dockerfile 里面添加：

```text
ENV GOPROXY=https://goproxy.cn,direct
# 关闭模块验证（可选，私有仓库需要）
ENV GOSUMDB=off
```


