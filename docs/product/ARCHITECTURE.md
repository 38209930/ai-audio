# Architecture

## Components

```text
apps/windows-client       Tauri + React desktop client
apps/local-engine         Local Python engine wrapper around current transcription pipeline
services/openresty-api    OpenResty/Lua cloud API
db/migrations             MySQL schema migrations
scripts                   Existing local Gradio and CLI tooling
```

## Runtime Flow

1. User launches the Windows client.
2. Client checks login token.
3. If unauthenticated, client performs phone login through OpenResty API.
4. User configures ASR models in Settings > Model Management.
5. User selects a video file. The UI shows filename, size, format, and duration only.
6. Client invokes local engine.
7. Local engine extracts audio, chunks it, transcribes it, and writes outputs.
8. If solution model is configured, client calls the user's configured LLM API locally and writes `solution.md`.
9. Client opens the output directory.

## Privacy Boundary

Cloud receives:

- Phone login requests
- Captcha events
- SMS code events
- Client device metadata
- Version checks
- Model catalog requests

Cloud does not receive:

- User videos
- Extracted audio
- Transcripts
- Generated documents
- User LLM API keys

## Cloud API

OpenResty provides:

- `/health`
- `/v1/captcha/challenge`
- `/v1/captcha/verify`
- `/v1/auth/sms/send`
- `/v1/auth/sms/login`
- `/v1/models/catalog`
- `/v1/versions/check`
- `/v1/devices/report`

## Local Engine

The local engine wraps the existing `scripts/transcribe_course.py` behavior. It should remain callable from:

- CLI
- Tauri command
- Future automated tests

## Data Storage

Cloud MySQL stores masked and hashed identifiers. Local client stores:

- Login token
- Device ID
- Model install metadata
- User settings
- Optional LLM provider config

API keys must use OS secure storage through Tauri-compatible credential storage.

