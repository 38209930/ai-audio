# Hardware Support And Time Estimates

These estimates are placeholders for the help center. Actual speed depends on model size, audio quality, driver, CPU, GPU, and compute type.

## Windows

| Hardware | Mode | Recommended Model | Expected Speed |
| --- | --- | --- | --- |
| Modern CPU only | CPU | small/medium | Slow, often near real-time or slower |
| NVIDIA RTX 3060 | CUDA | medium/large-v3 | Faster than real-time |
| NVIDIA RTX 4070/5070 Ti | CUDA | large-v3 | Much faster than real-time |
| Low VRAM GPU | CUDA | medium or int8_float16 | Stable fallback |

## macOS Future Version

| Hardware | Mode | Status |
| --- | --- | --- |
| Intel Mac | CPU | Future support |
| Apple Silicon M1/M2/M3/M4 | Apple acceleration route | Planned after Windows |

## Client Estimate Method

The client should show two estimates:

1. Static estimate from the hardware table.
2. Optional benchmark estimate from a short local audio run.

Final ETA should be shown as a range, not a precise promise.

