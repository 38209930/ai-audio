# 使用手册

本项目用于把课程视频转换成字幕、时间轴文稿、详细教程和实施方案。推荐通过可视化界面使用，也保留命令行方式。

## 1. 支持格式

推荐视频格式：

- `.mp4`
- `.mkv`
- `.mov`
- `.webm`
- `.avi`
- `.flv`

最佳实践：

- 优先使用 `.mp4`。
- 建议视频编码为 H.264，音频编码为 AAC。
- 文件名尽量使用英文、数字和下划线，例如 `course_01.mp4`。
- 中文文件名可以处理，但 WSL 终端可能显示乱码。
- 单个视频建议是一节课或一个主题。

## 2. 时长建议

脚本会自动把音频切成 10 分钟以内的片段，所以 25 分钟或 40 分钟视频不需要手动拆分。

建议：

- 0 到 60 分钟：可直接处理。
- 60 到 120 分钟：可处理，但建议保持电脑空闲，避免休眠。
- 超过 120 分钟：建议按章节拆成多个视频。

如果处理失败，可以在界面勾选“稳定模式”，或命令行使用：

```bash
--segment-seconds 300 --compute-type int8_float16
```

## 3. 启动可视化界面

在 PowerShell 中进入项目目录：

```powershell
cd E:\AI-PROJECT\ai-audio
```

启动：

```powershell
.\启动可视化界面.ps1
```

浏览器打开：

```text
http://127.0.0.1:7860
```

界面流程：

1. 点击“检查模型”。
2. 如果模型缺失，点击“检查/下载模型”。
3. 上传一个视频。
4. 保持默认参数：`zh`、`600 秒`、`cuda`、`float16`。
5. 如果担心稳定性，勾选“稳定模式”。
6. 点击“开始转写并生成文档”。
7. 下载 SRT、Markdown 时间轴文稿、详细教程和实施方案。

## 4. 模型下载

默认模型：

- `Systran/faster-whisper-large-v3`

镜像地址：

- https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main

原始地址：

- https://huggingface.co/Systran/faster-whisper-large-v3

本地模型目录：

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

在 WSL 中运行：

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
- `.md`：带时间戳的文字稿。
- `tutorial.md`：课程内容整理稿。
- `implementation_plan.md`：实施方案草稿。

## 7. 常见问题

### 显存不足

使用稳定模式，或命令行参数：

```bash
--segment-seconds 300 --compute-type int8_float16
```

### 字幕专有名词错误

faster-whisper 对工具名、品牌名、人名可能识别不准，正式发布前建议人工校对。

### 处理中文文件名失败

把视频改成英文文件名后重试。

### Web UI 端口打不开

检查服务是否运行：

```powershell
wsl.exe -d Ubuntu-22.04 -- pgrep -af scripts/app.py
```

停止服务：

```powershell
wsl.exe -d Ubuntu-22.04 -- pkill -f scripts/app.py
```
