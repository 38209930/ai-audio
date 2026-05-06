# Development Guide

This document describes the project structure, local development workflow, and release checklist.

## Architecture

The project has three layers:

- `scripts/transcribe_course.py`: core transcription pipeline and CLI.
- `scripts/app.py`: Gradio Web UI and upload/model-management wrapper.
- `scripts/setup_wsl_faster_whisper.sh`: WSL environment bootstrap.

The commercial desktop roadmap adds:

- `apps/windows-client`: Tauri + React Windows client.
- `apps/local-engine`: desktop-facing local engine wrapper.
- `services/openresty-api`: OpenResty/Lua cloud API.
- `db/migrations`: MySQL schema.
- `docs/product`: versioned implementation plan and product contracts.

The transcription pipeline:

1. Validates the input video and model directory.
2. Extracts audio with ffmpeg into `full.wav`.
3. Splits audio into fixed-length `.wav` chunks.
4. Loads faster-whisper with CTranslate2.
5. Transcribes each chunk and offsets timestamps globally.
6. Writes SRT, Markdown transcript, tutorial draft, and implementation-plan draft.

## Local Setup

Inside WSL:

```bash
bash scripts/setup_wsl_faster_whisper.sh
source ~/venvs/faster-whisper/env.sh
```

Run the Web UI:

```bash
bash scripts/run_webui.sh
```

Run the CLI:

```bash
python scripts/transcribe_course.py input/course_01.mp4 \
  --language zh \
  --model models/faster-whisper-large-v3 \
  --device cuda \
  --compute-type float16
```

## Key Files

```text
scripts/app.py
scripts/transcribe_course.py
scripts/setup_wsl_faster_whisper.sh
scripts/run_webui.sh
启动可视化界面.ps1
docs/USAGE.zh-CN.md
```

## Validation

Syntax check:

```bash
python -m py_compile scripts/transcribe_course.py scripts/app.py
```

GPU check:

```bash
nvidia-smi
```

Minimal smoke test:

```bash
ffmpeg -y \
  -f lavfi -i testsrc=size=320x180:rate=10 \
  -f lavfi -i sine=frequency=440:duration=2 \
  -t 2 -pix_fmt yuv420p /tmp/ai-audio-smoke.mp4

python scripts/transcribe_course.py /tmp/ai-audio-smoke.mp4 \
  --output-dir /tmp/ai-audio-smoke \
  --model models/faster-whisper-large-v3 \
  --language en \
  --segment-seconds 60 \
  --device cuda \
  --compute-type float16
```

The sine-wave test may produce zero subtitle cues, but it should still generate all output files.

## Model Management

Required model files are defined in `REQUIRED_MODEL_FILES` in `scripts/transcribe_course.py`.

The Web UI downloads from:

```text
https://hf-mirror.com/Systran/faster-whisper-large-v3
```

Download uses `huggingface_hub.snapshot_download()` with `allow_patterns` limited to the required model files.

## Coding Guidelines

- Keep the CLI usable without the Web UI.
- Keep generated files out of Git.
- Do not commit model files or videos.
- Prefer deterministic Markdown generation over remote LLM calls.
- Keep defaults conservative for long videos.
- Preserve Windows + WSL compatibility.

## Release Checklist

Before publishing a new release:

1. Run syntax checks.
2. Launch the Web UI locally.
3. Verify model check and GPU status.
4. Run a short smoke transcription.
5. Confirm `.gitignore` excludes models, uploads, outputs, logs, and media.
6. Update README and usage docs if CLI or UI behavior changed.

## Known Limitations

- Tutorial and implementation-plan files are generated from transcript text and should be reviewed.
- Diarization and speaker labels are not currently implemented.
- Batch upload is not currently implemented.
- Long videos rely on local disk space for extracted WAV files.
