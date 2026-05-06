# Windows Client

Tauri + React shell for the commercial Windows version.

## Prerequisites

- Node.js 22+
- Rust stable toolchain
- Tauri v2 prerequisites for Windows

## Development

```bash
npm install
npm --workspace apps/windows-client run dev
```

Tauri development:

```bash
npm --workspace apps/windows-client run tauri dev
```

Current status is v0.1 skeleton. Pages are placeholders for:

- Home
- Phone login
- Transcription tasks
- Model management
- Help
- Version updates

The UI must not preview selected videos or images. It should show filename, size, format, duration, and task status only.

