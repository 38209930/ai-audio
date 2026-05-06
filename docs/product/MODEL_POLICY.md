# Model Policy

The default model list uses a conservative commercial-use policy. Only models with clear permissive licensing should appear as default downloadable models.

## First ASR Catalog

| Model | Use | License | Commercial Status | Notes |
| --- | --- | --- | --- | --- |
| Systran/faster-whisper-large-v3 | ASR | MIT | Allowed under MIT terms | Recommended GPU model |
| Systran/faster-whisper-medium | ASR | MIT | Allowed under MIT terms | Lower VRAM fallback |
| Systran/faster-whisper-small | ASR | MIT | Allowed under MIT terms | CPU-friendly fallback |

## Required Catalog Fields

- `id`
- `displayName`
- `provider`
- `task`
- `license`
- `commercialUse`
- `downloadUrl`
- `manualDownloadUrl`
- `requiredFiles`
- `recommendedHardware`
- `estimatedSpeed`

## API-Key Based Models

Solution-generation models are not downloaded by the app. The user configures:

- Provider
- Base URL
- API key
- Model name

The UI should state that API usage, pricing, and commercial terms are controlled by the selected provider.

## FFmpeg Policy

Commercial builds must use an LGPL-compliant FFmpeg distribution and avoid GPL/nonfree builds unless the whole distribution strategy is legally reviewed.

