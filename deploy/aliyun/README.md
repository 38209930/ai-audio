# 阿里云 ECS 部署手册

本目录包含 AI Audio 云端 API 在阿里云 ECS 上部署所需的脚本和模板。完整说明见：

```text
docs/DEPLOYMENT.zh-CN.md
```

## 部署约定

- 项目目录：`/home/ai-audio/api`
- API 容器：`ai-audio-openresty`
- 容器监听：`127.0.0.1:8080`
- HTTPS 入口：ECS Nginx
- SSL 证书：`/home/ssl/ccun.net.pem`
- SSL 私钥：`/home/ssl/ccun.net.key`
- 推荐 Redis：ECS 本机 Redis，`REDIS_HOST=172.17.0.1`

## 文件说明

```text
env.example                 环境变量模板，复制为 .env 后填写
docker-compose.aliyun.yml   OpenResty API 容器编排
nginx-https.example.conf    Nginx HTTPS 反代模板
apply-migrations.sh         执行 MySQL migrations
render-nginx-conf.sh        根据 .env 渲染 Nginx 配置并 reload
restart-api.sh              构建、重启 API，并执行 smoke test
smoke-test.sh               本机 API 验收测试
```

`.env` 包含密钥和服务器信息，已被 `.gitignore` 忽略，禁止提交。

## 快速部署

```bash
sudo mkdir -p /home/ai-audio/api
sudo chown -R "$USER":"$USER" /home/ai-audio
git clone https://github.com/38209930/ai-audio.git /home/ai-audio/api
cd /home/ai-audio/api
cp deploy/aliyun/env.example deploy/aliyun/.env
vim deploy/aliyun/.env
bash deploy/aliyun/apply-migrations.sh
bash deploy/aliyun/restart-api.sh
```

## Redis 推荐配置

ECS 本机 Redis 推荐绑定：

```text
bind 127.0.0.1 ::1 172.17.0.1
protected-mode yes
requirepass <REDIS_PASSWORD>
```

`.env` 中配置：

```text
REDIS_HOST=172.17.0.1
REDIS_PORT=6379
```

## HTTPS

`.env` 中设置：

```text
API_DOMAIN=<你的 API 域名>
```

渲染 Nginx：

```bash
cd /home/ai-audio/api
bash deploy/aliyun/render-nginx-conf.sh
```

公网 DNS 需要添加：

```text
<API_DOMAIN> -> ECS 公网 IP
```

如果 DNS 尚未生效，可以在 ECS 上验证：

```bash
curl -k -fsS --resolve <API_DOMAIN>:443:127.0.0.1 https://<API_DOMAIN>/health
```

## 验收

```bash
cd /home/ai-audio/api
bash deploy/aliyun/smoke-test.sh http://127.0.0.1:8080
```

验收通过时应满足：

- `/health` 返回 `status=ok`
- MySQL 为 `ok`
- Redis 为 `ok`
- 游客登录返回 30 天试用 token
- 验证码 challenge 返回 base64 SVG

## 短信登录

短信资料未配置时：

```text
SMS_DRY_RUN=false
ALIYUN_SMS_ACCESS_KEY_ID=
ALIYUN_SMS_ACCESS_KEY_SECRET=
ALIYUN_SMS_SIGN_NAME=
ALIYUN_SMS_TEMPLATE_CODE=
```

此时 `/v1/auth/sms/send` 返回 `SMS_NOT_CONFIGURED`，不影响游客试用。

仅闭环测试时可设置：

```text
SMS_DRY_RUN=true
```

该模式会返回 `devCode`，不得用于公网测试。

## 维护

更新并重启：

```bash
cd /home/ai-audio/api
git pull
bash deploy/aliyun/apply-migrations.sh
bash deploy/aliyun/restart-api.sh
```

查看日志：

```bash
docker logs -f ai-audio-openresty
```

容器状态：

```bash
cd /home/ai-audio/api/deploy/aliyun
docker compose -f docker-compose.aliyun.yml --env-file .env ps
```
