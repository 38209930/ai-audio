# AI Audio 使用说明书

AI Audio 是一个本地视频课程转写工具，可以把课程视频转换为：

- `SRT` 字幕文件
- 带时间轴的 Markdown 文稿
- 详细教程草稿
- 实施方案草稿

当前推荐普通用户使用 **Windows 便携客户端**。开发者或高级用户也可以使用本地 Web UI 和命令行。

## 1. 适用场景

AI Audio 适合处理：

- 视频课程
- 录屏教程
- 会议录制
- 访谈视频
- 需要二次整理成学习笔记或执行方案的视频资料

不适合直接处理：

- 背景噪声非常大的视频
- 多人同时说话严重重叠的视频
- 音频缺失、音轨损坏或加密保护的视频文件

## 2. Windows 便携版快速开始

便携版无需安装，解压后即可运行。

目录结构：

```text
AI-Audio-Windows-Portable/
  AI Audio.exe
  engine/
  python/
  ffmpeg/
  models/
  output/
```

使用步骤：

1. 解压 `AI-Audio-Windows-Portable`。
2. 双击 `AI Audio.exe`。
3. 进入“模型管理”，下载一个 ASR 模型，或手动放入模型文件。
4. 进入“转写任务”，选择视频文件。
5. 确认语言、设备、精度、切片秒数。
6. 点击“开始转写并生成文档”。
7. 完成后点击“打开目录”查看结果。

便携版默认本地免登录使用，不需要手机号、验证码或游客试用 token。

## 3. 视频文件要求

支持格式：

- `.mp4`
- `.mkv`
- `.mov`
- `.webm`
- `.avi`
- `.flv`

推荐格式：

- 视频编码：H.264
- 音频编码：AAC
- 容器格式：`.mp4`

文件名可以使用中文。若命令行排错，建议使用英文、数字、下划线命名，例如：

```text
course_01.mp4
```

## 4. 视频时长建议

AI Audio 会先提取音频，再按片段转写，不会把整条视频一次性放入显存。

建议：

- `0-60 分钟`：可直接处理。
- `60-120 分钟`：可处理，建议保持电脑不要休眠。
- `超过 120 分钟`：建议按章节拆成多个视频。

默认切片长度：

```text
600 秒
```

如果显存不足、处理失败或机器不稳定，建议开启稳定模式：

```text
切片秒数：300
计算精度：int8_float16
```

CPU 模式也可使用，但速度会明显慢于 NVIDIA GPU。

## 5. 模型准备

首次使用必须准备 ASR 模型，否则无法开始转写。

默认模型目录：

```text
models/
```

模型会放入对应子目录：

```text
models/faster-whisper-large-v3/
models/faster-whisper-medium/
models/faster-whisper-small/
```

模型清单：

| 模型 | 适用场景 | 建议硬件 |
| --- | --- | --- |
| `Systran/faster-whisper-large-v3` | 默认推荐，质量优先 | NVIDIA GPU，显存建议 8GB+ |
| `Systran/faster-whisper-medium` | 速度和质量折中 | NVIDIA GPU 或较强 CPU |
| `Systran/faster-whisper-small` | 低显存、CPU、快速测试 | CPU 可用，GPU 更快 |

下载地址：

- large-v3 镜像：https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main
- large-v3 原始：https://huggingface.co/Systran/faster-whisper-large-v3
- medium 镜像：https://hf-mirror.com/Systran/faster-whisper-medium/tree/main
- medium 原始：https://huggingface.co/Systran/faster-whisper-medium
- small 镜像：https://hf-mirror.com/Systran/faster-whisper-small/tree/main
- small 原始：https://huggingface.co/Systran/faster-whisper-small

每个模型目录必须包含：

```text
config.json
model.bin
preprocessor_config.json
tokenizer.json
vocabulary.json
```

如果软件内下载失败，可以手动下载以上文件到对应目录，然后在“模型管理”中点击“重新扫描”。

## 6. 转写参数说明

常用参数：

| 参数 | 推荐值 | 说明 |
| --- | --- | --- |
| 语言代码 | `zh` | 中文视频使用 `zh`，留空可自动检测 |
| 切片秒数 | `600` | 默认每段 10 分钟以内 |
| 设备 | `cuda` | NVIDIA GPU 用户推荐 |
| 计算精度 | `float16` | GPU 默认推荐 |
| 稳定模式 | 关闭 | 失败或显存不足时开启 |

稳定模式会自动使用：

```text
切片秒数：300
计算精度：int8_float16
```

CPU 模式建议：

```text
设备：cpu
计算精度：int8
切片秒数：300
```

## 7. 输出文件说明

默认输出目录：

```text
output/<视频名>/
```

输出结构：

```text
output/<视频名>/
  audio/
    full.wav
    segments/
      part_000.wav
      part_001.wav
  transcripts/
    <视频名>.srt
    <视频名>.md
  analysis/
    tutorial.md
    implementation_plan.md
```

文件说明：

- `transcripts/<视频名>.srt`：字幕文件，可导入播放器或剪辑软件。
- `transcripts/<视频名>.md`：带时间轴的 Markdown 转写文稿。
- `analysis/tutorial.md`：根据字幕整理出的详细教程草稿。
- `analysis/implementation_plan.md`：根据课程内容整理出的实施方案草稿。
- `audio/full.wav`：从视频提取出的完整音频。
- `audio/segments/`：自动切分后的音频片段。

生成的教程和实施方案是规则化草稿，正式发布或交付前建议人工校对和润色。

## 8. 本地 Web UI 使用

Web UI 适合开发者或已配置 WSL 环境的用户。

在 PowerShell 进入项目目录：

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

操作流程：

1. 检查 GPU 和模型状态。
2. 上传一个视频文件。
3. 设置语言、设备、精度和切片秒数。
4. 点击开始转写。
5. 下载生成的 SRT、Markdown 文稿、教程和实施方案。

## 9. 命令行使用

在 WSL 或已配置 Python 环境中执行。

GPU 默认模式：

```bash
source ~/venvs/faster-whisper/env.sh
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --segment-seconds 600 \
  --device cuda \
  --compute-type float16
```

GPU 稳定模式：

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

## 10. 硬件与耗时参考

实际速度取决于视频音质、模型大小、CPU/GPU、磁盘速度和显存状态。

粗略参考：

| 硬件 | 推荐模型 | 25 分钟视频参考 |
| --- | --- | --- |
| NVIDIA GPU 8GB+ | large-v3 | 通常明显快于 CPU |
| NVIDIA GPU 低显存 | medium 或 small | 建议稳定模式 |
| 普通 CPU | small 或 medium | 可能需要数倍视频时长 |

如果电脑风扇明显升高、显存占满或任务失败，优先切换稳定模式。

## 11. 常见问题

### 模型未就绪

进入“模型管理”，检查缺失文件。可以点击下载，也可以手动下载到指定目录后重新扫描。

### GPU 不可用

Windows 便携版需要本机 NVIDIA 驱动正常，并且 CUDA/cuDNN 运行库可被本地 engine 加载。若 GPU 模式失败，先切换：

```text
设备：cpu
计算精度：int8
```

### 显存不足

使用稳定模式：

```text
切片秒数：300
计算精度：int8_float16
```

也可以换用 `medium` 或 `small` 模型。

### 转写内容有错字

专有名词、品牌名、人名、软件名可能识别不准。正式使用前建议人工校对 SRT 和 Markdown 文稿。

### Web UI 打不开

检查服务是否运行：

```powershell
wsl.exe -d Ubuntu-22.04 -- pgrep -af scripts/app.py
```

停止服务：

```powershell
wsl.exe -d Ubuntu-22.04 -- pkill -f scripts/app.py
```

### 便携版打不开

确认系统已安装 Microsoft Edge WebView2 Runtime。Windows 11 通常已自带。

### 输出目录没有文件

检查界面错误提示。常见原因：

- 视频文件路径无权限访问
- 模型文件不完整
- ffmpeg 运行失败
- GPU 模式加载失败
- 磁盘空间不足

## 12. 数据与隐私

Windows 便携版和本地 Web UI 的视频处理默认在本机完成：

- 视频文件不上传云端。
- 字幕和 Markdown 文稿不上传云端。
- 模型文件保存在本地模型目录。
- 输出文件保存在本地 `output/` 目录。

后续如接入云端账号、版本更新或大模型 API，应以对应版本的隐私说明为准。
