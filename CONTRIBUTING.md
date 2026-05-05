# Contributing

Contributions are welcome. The project is intentionally small and practical, so the best contributions improve reliability, documentation, or the local user experience.

## Good First Contributions

- Improve setup instructions for different GPUs or Linux distributions.
- Add troubleshooting notes for CUDA, cuDNN, WSL, or ffmpeg errors.
- Improve the Web UI labels and status messages.
- Add tests around SRT formatting and timestamp offsets.
- Improve generated tutorial or implementation-plan templates.

## Development Workflow

1. Fork the repository.
2. Create a feature branch.
3. Make a focused change.
4. Run validation:

```bash
python -m py_compile scripts/transcribe_course.py scripts/app.py
```

5. Open a pull request with:

- What changed
- Why it changed
- How it was tested

## Ground Rules

- Do not commit generated outputs.
- Do not commit model files.
- Do not commit user videos or audio files.
- Keep CLI compatibility when changing the Web UI.
- Prefer clear docs over clever abstractions.

## Security

The Web UI is intended for local use on `127.0.0.1`. Do not expose it to the public internet without adding authentication and reviewing file-upload risks.
