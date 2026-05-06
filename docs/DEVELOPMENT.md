# AI Audio 开发文档

本文档面向参与开发和维护的工程师，说明项目结构、开发环境、核心流程、接口边界和验证方式。

## 1. 项目结构

```text
apps/windows-client       Tauri + React Windows 客户端
apps/local-engine         面向桌面端的本地 Python 引擎封装
services/openresty-api    OpenResty/Lua 云端 API
db/migrations             MySQL 数据库迁移
scripts                   本地 Gradio Web UI、CLI 和 WSL 安装脚本
deploy/aliyun             阿里云 ECS 部署脚本和模板
docs                      用户、开发、部署和产品文档
```

## 2. 核心能力

本地转写流水线：

1. 校验视频路径和模型目录。
2. 使用 ffmpeg 提取 16 kHz 单声道 WAV。
3. 按固定秒数切分音频，默认 600 秒。
4. 使用 faster-whisper 转写每个音频片段。
5. 将片段时间轴偏移合并成全局时间轴。
6. 输出 SRT、Markdown 时间轴文稿、教程草稿和实施方案草稿。

云端 API：

- 游客试用 30 天。
- 手机号验证码登录接口，短信未配置时返回 `SMS_NOT_CONFIGURED`。
- 图形点选验证码。
- 模型清单。
- 版本检查。
- 设备上报。

客户端：

- 当前是 Tauri + React 产品骨架。
- 游客试用入口已经接入云端 API。
- 模型管理、任务、帮助、更新和捐助页面为产品化入口。

## 3. 本地开发环境

推荐环境：

- Windows 11
- WSL2 Ubuntu 22.04
- Python 3.10+
- Node.js 20+
- ffmpeg
- NVIDIA GPU 和 WSL CUDA 支持

安装 faster-whisper 环境：

```bash
bash scripts/setup_wsl_faster_whisper.sh
source ~/venvs/faster-whisper/env.sh
```

启动本地 Web UI：

```bash
bash scripts/run_webui.sh
```

启动 Windows 客户端开发构建：

```bash
npm install
npm --workspace apps/windows-client run build
```

## 4. 本地 CLI 开发

示例：

```bash
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --segment-seconds 600 \
  --device cuda \
  --compute-type float16
```

稳定模式：

```bash
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --segment-seconds 300 \
  --device cuda \
  --compute-type int8_float16
```

开发要求：

- CLI 必须能独立运行，不依赖 Gradio 或 Windows 客户端。
- 输出目录结构保持兼容。
- 不提交模型、视频、音频、输出文件和日志。

## 5. 云端 API 开发

服务目录：

```text
services/openresty-api/
```

核心约定：

- 所有响应包含 `ok`、`data`、`error`、`requestId`。
- MySQL 连接配置来自环境变量。
- Redis 用于验证码、验证码 token、限流和短期状态。
- 手机号、IP、验证码、API Key 不得写入日志明文。
- `.env` 不提交仓库。

主要接口见：

```text
docs/product/API_CONTRACT.md
```

本地 Docker 栈：

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

注意：OpenResty 容器将 API 代码挂载到 `/opt/ai-audio-api`，不能覆盖镜像自带的 `/usr/local/openresty/nginx`。

## 6. 数据库迁移

迁移文件位于：

```text
db/migrations/
```

当前迁移：

- `001_base_schema.sql`
- `002_seed_model_catalog.sql`
- `003_seed_app_versions.sql`
- `004_guest_trials.sql`

新增迁移规则：

- 只新增新编号文件，不修改已上线迁移，除非该迁移尚未发布。
- 表结构要兼容 MySQL 8。
- `TIMESTAMP NOT NULL` 字段必须给默认值或由 INSERT 明确写入，避免严格模式失败。

## 7. Windows 客户端开发

目录：

```text
apps/windows-client/
```

当前页面：

- 首页
- 登录
- 转写任务
- 模型管理
- 使用帮助
- 版本更新
- 捐助

客户端配置：

```text
apps/windows-client/src/apiConfig.ts
```

捐助图片：

```text
apps/windows-client/src/assets/donate/wechat-pay.png
apps/windows-client/src/assets/donate/wechat-official-account.png
```

开发要求：

- 页面文案使用 UTF-8 中文。
- 不展示视频预览，只展示文件名、大小、格式、时长。
- 用户视频、音频、字幕、文稿不上传云端。
- 用户自有 LLM API Key 后续必须存本机安全存储，不上传云端。

## 8. 验证命令

Python 编译检查：

```bash
python -m py_compile scripts/transcribe_course.py scripts/app.py apps/local-engine/engine_cli.py
```

Windows 客户端构建：

```bash
npm --workspace apps/windows-client run build
```

Git 空白检查：

```bash
git diff --check
```

ECS API smoke test：

```bash
bash deploy/aliyun/smoke-test.sh http://127.0.0.1:8080
```

## 9. 发布前检查

发布前必须确认：

- 本地构建和 Python 编译检查通过。
- ECS `/health` 返回 `status=ok`。
- MySQL 和 Redis 均为 `ok`。
- 游客登录可返回 30 天试用 token。
- 验证码 challenge 可生成。
- `.env`、密钥、密码、模型和媒体文件未进入 Git。
- README、使用文档、部署文档与当前行为一致。

## 10. 已知限制

- Windows 客户端当前仍是产品骨架，完整转写任务执行需要继续接入本地 engine。
- 手机号短信登录在短信资料未配置前不可用。
- 教程和实施方案是规则化草稿，正式使用前建议人工修订。
- macOS DMG 尚未开始实现。
