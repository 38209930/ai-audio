# AI Audio 使用说明书

AI Audio 用于把课程视频转换为字幕、带时间轴的 Markdown 文稿、详细教程和实施方案。当前项目包含两种使用方式：

- 本地 Web UI：适合个人处理视频课程，运行在 Windows + WSL。
- Windows 客户端雏形：包含游客试用、模型管理、转写任务、版本更新和捐助入口，后续会逐步接入完整本地引擎。

## 1. 视频要求

支持格式：

- `.mp4`
- `.mkv`
- `.mov`
- `.webm`
- `.avi`
- `.flv`

建议：

- 优先使用 `.mp4`。
- 推荐视频编码 H.264，音频编码 AAC。
- 单个视频建议是一节课或一个主题。
- 文件名可使用中文，但命令行排错时英文、数字、下划线更稳妥，例如 `course_01.mp4`。

## 2. 时长建议

系统会先提取音频，并按片段转写，不会把整条视频一次性放进显存。

- 0-60 分钟：可直接处理。
- 60-120 分钟：可处理，建议电脑不要休眠，并预留足够磁盘空间。
- 超过 120 分钟：建议按章节拆成多个视频。

默认切片长度是 600 秒。若处理失败或显存压力较大，使用稳定模式：

```bash
--segment-seconds 300 --compute-type int8_float16
```

## 3. 本地 Web UI 使用流程

在 PowerShell 进入项目目录：

```powershell
cd E:\AI-PROJECT\ai-audio
```

启动界面：

```powershell
.\启动可视化界面.ps1
```

浏览器打开：

```text
http://127.0.0.1:7860
```

操作步骤：

1. 检查 GPU 和模型状态。
2. 如果模型缺失，使用界面下载，或手动放入模型目录。
3. 上传一个视频文件。
4. 默认参数建议保持：`language=zh`、`segment_seconds=600`、`device=cuda`、`compute_type=float16`。
5. 如果需要更稳，选择稳定模式。
6. 点击开始转写。
7. 完成后下载 SRT、Markdown 时间轴文稿、详细教程和实施方案。

## 4. 模型文件

默认模型：

```text
Systran/faster-whisper-large-v3
```

下载地址：

- 镜像：https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main
- 原始：https://huggingface.co/Systran/faster-whisper-large-v3

本地目录：

```text
models/faster-whisper-large-v3/
```

必须包含：

```text
config.json
model.bin
preprocessor_config.json
tokenizer.json
vocabulary.json
```

## 5. 命令行使用

在 WSL 中执行：

```bash
source ~/venvs/faster-whisper/env.sh
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

CPU 模式：

```bash
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --segment-seconds 300 \
  --device cpu \
  --compute-type int8
```

## 6. 输出文件

输出目录：

```text
output/<视频名>/
```

主要文件：

```text
audio/full.wav
audio/segments/part_000.wav
transcripts/<视频名>.srt
transcripts/<视频名>.md
analysis/tutorial.md
analysis/implementation_plan.md
```

说明：

- `.srt`：字幕文件，可导入播放器或剪辑软件。
- `.md`：带时间戳的转写文稿。
- `tutorial.md`：按课程内容整理的教程草稿。
- `implementation_plan.md`：按课程内容整理的实施方案草稿。

## 7. Windows 客户端说明

当前 Windows 客户端是商业版产品骨架，已包含：

- 游客试用 30 天。
- 手机号登录占位，短信服务未配置前不开放。
- 模型管理入口。
- 转写任务入口。
- 使用帮助和版本更新入口。
- 捐助入口。

游客试用按设备 ID 计算，服务端记录试用开始和到期时间。试用到期后，客户端会阻止创建新任务。

捐助二维码素材路径：

```text
apps/windows-client/src/assets/donate/wechat-pay.png
apps/windows-client/src/assets/donate/wechat-official-account.png
```

如果图片不存在，客户端会显示“二维码待配置”。

## 8. 常见问题

### 显存不足

使用稳定模式：

```bash
--segment-seconds 300 --compute-type int8_float16
```

### GPU 不可见

在 WSL 中检查：

```bash
nvidia-smi
```

如果不可见，先确认 Windows NVIDIA 驱动和 WSL GPU 支持是否正常。

### 字幕专有名词错误

faster-whisper 对品牌名、工具名、人名可能识别不准，正式发布前建议人工校对。

### Web UI 打不开

检查服务进程：

```powershell
wsl.exe -d Ubuntu-22.04 -- pgrep -af scripts/app.py
```

停止服务：

```powershell
wsl.exe -d Ubuntu-22.04 -- pkill -f scripts/app.py
```

### 域名访问失败

如果 ECS 上 `curl --resolve <域名>:443:127.0.0.1 https://<域名>/health` 正常，但公网访问失败，通常是 DNS A 记录尚未生效。
