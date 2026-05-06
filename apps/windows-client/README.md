# Windows Client

Tauri + React Windows 便携客户端。当前版本对齐本地 Web UI 的核心能力：选择视频、检查/下载模型、设置转写参数、调用本地 engine 生成字幕和 Markdown 文档。

## Development

```bash
npm install
npm --workspace apps/windows-client run build
npm --workspace apps/windows-client run tauri dev
```

## Portable Build

在仓库根目录运行：

```powershell
npm run client:portable
```

输出：

```text
dist-portable/AI-Audio-Windows-Portable/
```

便携目录包含：

```text
AI Audio.exe
engine/
python/
ffmpeg/
models/
output/
```

模型文件不随包内置。用户首次进入“模型管理”后，可以在客户端中下载模型，也可以手动下载到 `models/faster-whisper-*/` 对应目录后重新扫描。

GPU 模式需要 Windows 能加载 NVIDIA CUDA/cuDNN DLL。构建便携包时可通过 `-CudaDllZipUrl` 把 DLL 压缩包复制到 `cuda/bin/`。

## UI Rules

- 本版本地免登录使用。
- 不展示视频或图片预览。
- 只显示原文件名、大小、格式、时长和本地路径。
- 用户视频、字幕、文稿不上传云端。
