# AI Audio 部署文档

本文档说明如何把 OpenResty/Lua 云端 API 部署到阿里云 ECS。当前部署已按以下约定整理：

- 项目目录：`/home/ai-audio/api`
- API 容器监听：`127.0.0.1:8080`
- 对外 HTTPS：Nginx 反向代理到 `127.0.0.1:8080`
- SSL 证书：`/home/ssl/ccun.net.pem`
- SSL 私钥：`/home/ssl/ccun.net.key`
- Redis 推荐：ECS 本机 Redis，容器通过 Docker 网关访问 `172.17.0.1:6379`

## 1. 服务器准备

推荐系统：

```text
Ubuntu 22.04 LTS
```

安装基础组件：

```bash
sudo apt-get update
sudo apt-get install -y git docker.io docker-compose-plugin mysql-client redis-server redis-tools nginx curl ca-certificates
sudo systemctl enable --now docker nginx
```

安全组建议：

- 放行 `80/tcp` 和 `443/tcp`。
- SSH 端口只允许可信 IP。
- MySQL 和 Redis 不对公网开放。

## 2. 代码目录

首次部署：

```bash
sudo mkdir -p /home/ai-audio/api
sudo chown -R "$USER":"$USER" /home/ai-audio
git clone https://github.com/38209930/ai-audio.git /home/ai-audio/api
cd /home/ai-audio/api
```

更新代码：

```bash
cd /home/ai-audio/api
git pull
```

## 3. 环境变量

复制模板：

```bash
cp deploy/aliyun/env.example deploy/aliyun/.env
```

编辑：

```bash
vim deploy/aliyun/.env
```

必须配置：

```text
API_DOMAIN=<你的 API 域名>
HMAC_SECRET=<随机长密钥>
JWT_SECRET=<随机长密钥>
MYSQL_HOST=<MySQL 地址>
MYSQL_PORT=3306
MYSQL_DATABASE=ai_audio
MYSQL_USER=<MySQL 用户>
MYSQL_PASSWORD=<MySQL 密码>
REDIS_HOST=172.17.0.1
REDIS_PORT=6379
REDIS_PASSWORD=<Redis 密码>
REDIS_DB=0
SMS_DRY_RUN=false
```

短信未配置时，保留阿里云短信字段为空即可。此时手机号登录接口会返回 `SMS_NOT_CONFIGURED`，游客试用仍可用。

## 4. MySQL 初始化

创建数据库和用户：

```sql
CREATE DATABASE ai_audio CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'ai_audio_api'@'%' IDENTIFIED BY 'replace-with-strong-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_audio.* TO 'ai_audio_api'@'%';
FLUSH PRIVILEGES;
```

执行迁移：

```bash
cd /home/ai-audio/api
bash deploy/aliyun/apply-migrations.sh
```

迁移包含：

- 基础用户、验证码、设备、模型、版本表。
- 模型清单种子数据。
- 版本种子数据。
- 游客 30 天试用表。

## 5. Redis 配置

推荐使用 ECS 本机 Redis，不对公网开放。

编辑 `/etc/redis/redis.conf`：

```text
bind 127.0.0.1 ::1 172.17.0.1
protected-mode yes
requirepass <REDIS_PASSWORD>
```

重启：

```bash
sudo systemctl enable --now redis-server
sudo systemctl restart redis-server
```

验证：

```bash
redis-cli -h 172.17.0.1 -p 6379 -a "$REDIS_PASSWORD" ping
```

应返回：

```text
PONG
```

如果使用阿里云托管 Redis，需要确认 ECS 主机和 Docker 容器都能连接该 Redis 地址。

## 6. 启动 API

```bash
cd /home/ai-audio/api
bash deploy/aliyun/restart-api.sh
```

该脚本会：

- 构建 OpenResty 镜像。
- 启动 `ai-audio-openresty` 容器。
- 渲染 Nginx HTTPS 配置。
- 执行本机 smoke test。

手动查看状态：

```bash
cd /home/ai-audio/api/deploy/aliyun
docker compose -f docker-compose.aliyun.yml --env-file .env ps
docker logs --tail 100 ai-audio-openresty
```

## 7. HTTPS 和域名

证书文件：

```text
/home/ssl/ccun.net.pem
/home/ssl/ccun.net.key
```

渲染 Nginx：

```bash
cd /home/ai-audio/api
bash deploy/aliyun/render-nginx-conf.sh
```

验证 Nginx：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

DNS 必须添加 A 记录：

```text
<API_DOMAIN> -> ECS 公网 IP
```

如果 DNS 尚未生效，可以在 ECS 上临时验证 HTTPS：

```bash
curl -k -fsS --resolve <API_DOMAIN>:443:127.0.0.1 https://<API_DOMAIN>/health
```

## 8. 验收测试

本机容器 API：

```bash
cd /home/ai-audio/api
bash deploy/aliyun/smoke-test.sh http://127.0.0.1:8080
```

应检查：

- `/health` 返回 `status=ok`。
- MySQL 为 `ok`。
- Redis 为 `ok`。
- `/v1/models/catalog` 使用 MySQL 数据源。
- `/v1/versions/check` 使用 MySQL 数据源。
- `/v1/auth/guest/login` 返回游客 token。
- `/v1/captcha/challenge` 返回 base64 SVG 验证码。

公网验证：

```bash
curl -fsS https://<API_DOMAIN>/health
```

如果公网失败但 `--resolve` 成功，优先检查 DNS 解析。

## 9. 常见故障

### Docker 构建卡住

优先使用当前 `openresty/openresty:jammy` 镜像。旧 Alpine 构建可能在 ECS 网络下卡住 `apk add`。

### 容器启动后立刻退出

查看日志：

```bash
docker logs --tail 100 ai-audio-openresty
```

常见原因：

- 把代码目录挂载到了 `/usr/local/openresty/nginx`，覆盖了镜像自带 OpenResty。
- Nginx 临时目录或日志目录指向只读挂载路径。

当前正确挂载路径：

```text
/opt/ai-audio-api
```

### MySQL 正常但 Redis unavailable

检查 ECS 本机：

```bash
redis-cli -h 172.17.0.1 -p 6379 -a "$REDIS_PASSWORD" ping
```

检查容器配置：

```bash
docker inspect ai-audio-openresty --format '{{range .Config.Env}}{{println .}}{{end}}' | grep REDIS
```

### HTTPS 本机正常但公网不通

在 ECS 上：

```bash
curl -k -fsS --resolve <API_DOMAIN>:443:127.0.0.1 https://<API_DOMAIN>/health
```

如果成功，说明 Nginx 和证书可用，问题通常是 DNS A 记录未配置或未生效。

## 10. 维护命令

重启 API：

```bash
cd /home/ai-audio/api
bash deploy/aliyun/restart-api.sh
```

只重启容器：

```bash
cd /home/ai-audio/api/deploy/aliyun
docker compose -f docker-compose.aliyun.yml --env-file .env restart openresty
```

查看日志：

```bash
docker logs -f ai-audio-openresty
```

更新代码并部署：

```bash
cd /home/ai-audio/api
git pull
bash deploy/aliyun/apply-migrations.sh
bash deploy/aliyun/restart-api.sh
```
