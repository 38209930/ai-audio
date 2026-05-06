# Product Implementation Plan

This plan turns the current local transcription utility into a commercial desktop product. The first production target is Windows. macOS DMG support starts after Windows validation.

## Version Roadmap

| Version | Goal | Main Deliverables |
| --- | --- | --- |
| v0.1 | Technical foundation | Monorepo layout, Tauri shell, local engine wrapper, OpenResty health API, MySQL base schema |
| v0.2 | Account login | Phone login, SMS code flow, device reporting, token storage |
| v0.3 | Anti-abuse | Click-Chinese-character captcha, SMS anti-bombing, rate limits, audit logs |
| v0.4 | Model management | Model catalog, download links, local model validation, required ASR setup |
| v0.5 | Transcription tasks | Productized video task flow, no media preview, output folder auto-open |
| v0.6 | Solution generation | User-provided OpenAI-compatible API config, optional `solution.md` |
| v0.7 | Help and ETA | Help center, hardware table, benchmark-based duration estimate |
| v0.8 | Updates | Version API, update notes, update page |
| v0.9 | Windows Beta | Installer, FFmpeg compliance pass, privacy documents, beta testing |
| v1.0 | Windows GA | Stable Windows release with auth, model management, transcription, optional solution output |
| v1.1 | Subtitle translation | Generate translated SRT/MD variants while preserving timestamps |
| v1.2 | macOS DMG | Apple Silicon support and macOS packaging |

## v0.1 Acceptance

- Windows app shell can start.
- Local engine CLI can execute a transcription using existing faster-whisper pipeline.
- OpenResty API exposes `/health`.
- MySQL migrations create the base schema.
- Repository layout supports future client/backend/engine work without breaking the current tool.

## v0.2 Acceptance

- Client cannot enter the main workflow when unauthenticated.
- Phone verification login returns access and refresh tokens.
- Login events record masked phone, hashed phone, masked IP, hashed IP, OS, app version, and device ID.
- Sensitive values are not written to plaintext logs.

## v0.3 Acceptance

- SMS cannot be sent until click-character captcha is solved.
- Captcha challenge is one-time, short-lived, and expires.
- Phone, IP, and device rate limits block repeated abuse.
- Failed attempts are audited with masked identifiers.

## v0.4 Acceptance

- No ASR model means transcription is disabled.
- Model catalog returns license, commercial-use status, download links, required files, and hardware notes.
- Client supports single model download, selected download, and manual placement instructions.

## v0.5 Acceptance

- Video selection displays only original filename, size, format, and duration.
- No video, reference image, target image, or result preview is shown.
- Output is compatible with the original version: SRT, Markdown timeline, tutorial.
- Completion opens the output directory.

## v0.6 Acceptance

- User configures provider, base URL, API key, and model locally.
- API key stays in local encrypted storage and is never uploaded to the cloud API.
- If not configured, solution generation is skipped.
- If configured, `solution.md` is generated from SRT/MD content.

## v0.7 Acceptance

- Help center includes supported formats, duration guidance, CPU/GPU/Apple Silicon notes, model download guidance, common failures, and license notes.
- Client can estimate processing time from a static hardware table and optional local benchmark.

## v0.8 Acceptance

- Client checks current version against cloud API.
- Update page distinguishes optional and forced updates.
- Update notes are rendered as Markdown.

## v0.9-v1.0 Acceptance

- Windows installer works on a clean machine.
- FFmpeg distribution uses a compliant LGPL build.
- Privacy policy and user agreement are included.
- Beta users can install, log in, configure models, transcribe, and export results.

