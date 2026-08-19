# Mailpit 本地邮件捕获服务

Mailpit 是仅用于本地开发的 SMTP 邮件捕获服务。应用发出的邮件不会投递到真实邮箱，可在 Web 界面查看邮件正文、HTML 样式和验证码。

服务默认只监听 `127.0.0.1`，不会暴露给局域网或公网。

## 快速启动

```bash
cd middleware/mailpit
./start.sh
```

启动后访问：

```text
http://127.0.0.1:8025
```

SMTP 服务地址：`127.0.0.1:1025`。

## 配置 Node 本地开发环境

在 Node 项目的 `config.js` 中设置邮件服务：

```js
mail: {
  host: '127.0.0.1',
  port: 1025,
  secure: false,
  from: 'YeYing Local <no-reply@localhost>'
}
```

Mailpit 默认不需要 SMTP 认证。若本地 `run/secrets.enc.json` 已配置 SMTP 凭据，Node 会尝试认证并导致投递失败；确认这些凭据只用于本地 Mailpit 时，可在 Node 项目中移除：

```bash
npm run secrets:remove MAIL_SMTP_USER
npm run secrets:remove MAIL_SMTP_PASSWORD
```

随后启动 Node 服务并触发钱包身份验证邮件：

```bash
npm run dev:secure
```

在 Mailpit Web 界面中打开新收到的邮件，即可验证邮件模板与验证码流程。

## 可选端口配置

需要修改端口或消息保留数量时，创建本地 `.env`：

```bash
cp .env.template .env
```

可配置项：

```dotenv
MAILPIT_SMTP_PORT=1025
MAILPIT_WEB_PORT=8025
MAILPIT_MAX_MESSAGES=500
```

`.env` 不会提交到仓库。

## 服务管理

```bash
./start.sh
./status.sh
./stop.sh
```

Mailpit 不保存邮件数据卷。停止并重新创建服务后，已捕获邮件会被清空。
