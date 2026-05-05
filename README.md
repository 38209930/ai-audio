# AI Audio Course Transcription

AI Audio is a local video-to-course-notes tool for creators, educators, and learners. It uploads a course video, extracts audio, splits it into safe chunks, transcribes it with faster-whisper, and generates:

- SRT subtitles
- Markdown timeline transcript
- Detailed course tutorial draft
- Implementation-plan draft

It includes a local Gradio Web UI and a command-line workflow. The default setup targets Windows + WSL2 + NVIDIA GPU, but the core Python workflow can also run on Linux.

## Features

- Local Web UI at `http://127.0.0.1:7860`
- GPU transcription with faster-whisper and CTranslate2
- Automatic audio extraction and chunking with ffmpeg
- Default 10-minute audio segments to reduce failure risk
- Automatic model check and optional download from `hf-mirror.com`
- Offline local model support
- Downloadable `.srt`, `.md`, `tutorial.md`, and `implementation_plan.md`
- Stable mode for lower VRAM usage: 5-minute chunks and `int8_float16`

## Screens

The app is intentionally local-first:

1. Start the Web UI.
2. Upload one video.
3. Check or download the model.
4. Click transcription.
5. Download the generated files.

## Requirements

Recommended environment:

- Windows 11
- WSL2 with Ubuntu 22.04
- NVIDIA GPU with WSL CUDA support
- Python 3.10+
- ffmpeg in WSL
- GitHub CLI only if you plan to publish or contribute

The project has been validated on RTX 5070 Ti with faster-whisper `large-v3`.

## Quick Start

Clone the repository:

```bash
git clone https://github.com/38209930/ai-audio.git
cd ai-audio
```

Install inside WSL:

```bash
bash scripts/setup_wsl_faster_whisper.sh
```

Start the Web UI from PowerShell:

```powershell
.\启动可视化界面.ps1
```

Open:

```text
http://127.0.0.1:7860
```

If the model is missing, click **检查/下载模型** in the Web UI. The default model is:

- Mirror: https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main
- Original: https://huggingface.co/Systran/faster-whisper-large-v3

## Command-Line Usage

Activate the environment and run:

```bash
source ~/venvs/faster-whisper/env.sh
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --segment-seconds 600 \
  --device cuda \
  --compute-type float16
```

For a more conservative mode:

```bash
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --segment-seconds 300 \
  --device cuda \
  --compute-type int8_float16
```

## Output

For `input/course_01.mp4`, output is written to:

```text
output/course_01/
  audio/full.wav
  audio/segments/part_000.wav
  transcripts/course_01.srt
  transcripts/course_01.md
  analysis/tutorial.md
  analysis/implementation_plan.md
```

Large media files, generated outputs, and model files are ignored by Git.

## Documentation

- Chinese user guide: [docs/USAGE.zh-CN.md](docs/USAGE.zh-CN.md)
- Development guide: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- Contributing guide: [CONTRIBUTING.md](CONTRIBUTING.md)

## Model Files

By default, the local model directory is:

```text
models/faster-whisper-large-v3/
```

Required files:

```text
config.json
model.bin
preprocessor_config.json
tokenizer.json
vocabulary.json
```

The Web UI can download them automatically from `hf-mirror.com`. Manual download is also supported.

## Project Status

This project is a practical local workflow tool. The transcription pipeline is implemented and tested; the tutorial and implementation-plan outputs are deterministic drafts generated from the transcript and are intended for review and editing.

## License

MIT License. See [LICENSE](LICENSE).
