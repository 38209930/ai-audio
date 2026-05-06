# AI Audio 使用说明书

AI Audio 用于把课程视频转换为字幕、带时间轴的 Markdown 文稿、详细教程和实施方案。当前项目包含三种使用方式：

- Windows 便携客户端：适合普通用户，解压后运行，不要求安装 WSL、Python 或 ffmpeg。
- 本地 Web UI：适合个人处理视频课程，运行在 Windows + WSL。
- 命令行：适合开发者和批处理场景。

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

## 3. Windows 便携版使用流程

便携版目录结构：

```text
AI-Audio-Windows-Portable/
  AI Audio.exe
  engine/
  python/
  ffmpeg/
  models/
  output/
```

启动：

1. 解压便携包。
2. 双击 `AI Audio.exe`。
3. 首次进入“模型管理”，下载一个 ASR 模型，或手动放入模型文件。
4. 回到“转写任务”，选择视频并开始处理。

默认模型目录：

```text
models/
```

模型会按模型名称放入子目录，例如：

```text
models/faster-whisper-large-v3/
models/faster-whisper-medium/
models/faster-whisper-small/
```

模型清单：

- `Systran/faster-whisper-large-v3`：质量优先，推荐 NVIDIA GPU。
- `Systran/faster-whisper-medium`：速度和质量折中。
- `Systran/faster-whisper-small`：CPU、低显存或快速测试备用。

便携版不内置模型文件，避免包体过大。软件内下载优先使用：

```text
https://hf-mirror.com
```

如果软件下载失败，可打开界面中的镜像下载页或 Hugging Face 原始页，手动下载必需文件到对应目录，然后点击“重新扫描”。

便携版默认本地免登录使用，不需要手机号、验证码或游客试用 token。

NVIDIA GPU 模式需要显卡驱动和 CUDA/cuDNN 运行库可被本地 engine 加载。若 GPU 模式失败，可先切换 CPU 模式或稳定模式完成处理。

## 4. 本地 Web UI 使用流程

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

## 5. 模型文件

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

## 6. 命令行使用

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

## 7. 输出文件

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

## 8. Windows 客户端说明

当前 Windows 便携客户端已包含：

- 本地免登录使用。
- 模型管理、模型扫描和模型下载。
- 视频文件选择和信息读取。
- CPU/GPU、精度、切片长度和稳定模式参数。
- 本地转写任务。
- 输出目录打开入口。
- 使用帮助、版本更新说明和捐助入口。

捐助二维码素材路径：

```text
apps/windows-client/src/assets/donate/wechat-pay.png
apps/windows-client/src/assets/donate/wechat-official-account.png
```

如果图片不存在，客户端会显示“二维码待配置”。

## 9. 常见问题

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
