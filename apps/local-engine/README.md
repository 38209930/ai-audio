# Local Engine

This package wraps the current Python transcription pipeline for desktop-client use.

Current status:

- `engine_cli.py --version` works as a smoke test.
- `engine_cli.py transcribe <video>` delegates to `scripts/transcribe_course.py`.

Future Tauri commands should call this engine rather than importing the older Gradio app.

