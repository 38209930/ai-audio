#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

ENGINE_FILE = Path(__file__).resolve()
if (ENGINE_FILE.parent.parent / "scripts" / "transcribe_course.py").is_file():
    REPO_ROOT = ENGINE_FILE.parent.parent
else:
    REPO_ROOT = ENGINE_FILE.parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from transcribe_course import (  # noqa: E402
    DEFAULT_MODEL,
    REQUIRED_MODEL_FILES,
    format_md_time,
    probe_duration,
    process_video,
)

ENGINE_VERSION = "0.2.0"
HF_MIRROR = "https://hf-mirror.com"
HF_ORIGINAL = "https://huggingface.co"

MODEL_CATALOG = [
    {
        "id": "large-v3",
        "repo": "Systran/faster-whisper-large-v3",
        "dir": "faster-whisper-large-v3",
        "name": "faster-whisper large-v3",
        "purpose": "质量优先，适合课程和长视频",
        "hardware": "推荐 NVIDIA GPU，显存建议 8GB+",
        "size": "约 3GB",
    },
    {
        "id": "medium",
        "repo": "Systran/faster-whisper-medium",
        "dir": "faster-whisper-medium",
        "name": "faster-whisper medium",
        "purpose": "速度和质量折中",
        "hardware": "推荐 NVIDIA GPU，CPU 也可运行但较慢",
        "size": "约 1.5GB",
    },
    {
        "id": "small",
        "repo": "Systran/faster-whisper-small",
        "dir": "faster-whisper-small",
        "name": "faster-whisper small",
        "purpose": "低显存、CPU 或快速测试备用",
        "hardware": "CPU 可用，NVIDIA GPU 更快",
        "size": "约 500MB",
    },
]


def emit(payload: dict[str, Any]) -> None:
    data = json.dumps(payload, ensure_ascii=False) + "\n"
    sys.stdout.buffer.write(data.encode("utf-8"))
    sys.stdout.flush()


def model_dir(args: argparse.Namespace) -> Path:
    if args.model_dir:
        return Path(args.model_dir).expanduser().resolve()
    return (REPO_ROOT / DEFAULT_MODEL).resolve()


def missing_model_files(path: Path) -> list[str]:
    return [name for name in REQUIRED_MODEL_FILES if not (path / name).is_file()]


def catalog(args: argparse.Namespace) -> None:
    root = model_dir(args)
    emit(
        {
            "modelRoot": str(root),
            "requiredFiles": list(REQUIRED_MODEL_FILES),
            "models": [
                {
                    **item,
                    "mirrorUrl": f"{HF_MIRROR}/{item['repo']}/tree/main",
                    "originalUrl": f"{HF_ORIGINAL}/{item['repo']}",
                    "targetDir": str(root / item["dir"]),
                    "missingFiles": missing_model_files(root / item["dir"]),
                }
                for item in MODEL_CATALOG
            ],
        }
    )


def model_status(args: argparse.Namespace) -> None:
    root = model_dir(args)
    models = []
    for item in MODEL_CATALOG:
        target = root / item["dir"]
        missing = missing_model_files(target)
        models.append(
            {
                **item,
                "targetDir": str(target),
                "ready": not missing,
                "missingFiles": missing,
                "mirrorUrl": f"{HF_MIRROR}/{item['repo']}/tree/main",
                "originalUrl": f"{HF_ORIGINAL}/{item['repo']}",
            }
        )
    emit({"modelRoot": str(root), "requiredFiles": list(REQUIRED_MODEL_FILES), "models": models})


def download_model(args: argparse.Namespace) -> None:
    try:
        from huggingface_hub import snapshot_download
    except Exception as exc:  # pragma: no cover - depends on runtime packaging
        raise RuntimeError("缺少 huggingface_hub，无法下载模型。请检查便携版 Python 依赖。") from exc

    item = next((model for model in MODEL_CATALOG if model["id"] == args.model_id), None)
    if item is None:
        raise ValueError(f"未知模型：{args.model_id}")

    root = model_dir(args)
    target = root / item["dir"]
    target.mkdir(parents=True, exist_ok=True)
    os.environ["HF_ENDPOINT"] = HF_MIRROR
    emit({"event": "download_start", "modelId": item["id"], "targetDir": str(target)})
    snapshot_download(
        repo_id=item["repo"],
        endpoint=HF_MIRROR,
        local_dir=target,
        allow_patterns=list(REQUIRED_MODEL_FILES),
        max_workers=4,
    )
    emit(
        {
            "event": "download_complete",
            "modelId": item["id"],
            "targetDir": str(target),
            "missingFiles": missing_model_files(target),
        }
    )


def probe(args: argparse.Namespace) -> None:
    path = Path(args.video).expanduser().resolve()
    duration = probe_duration(path)
    emit(
        {
            "path": str(path),
            "fileName": path.name,
            "format": path.suffix.lower(),
            "sizeBytes": path.stat().st_size,
            "durationSeconds": duration,
            "durationText": format_md_time(duration),
        }
    )


def gpu_status(_: argparse.Namespace) -> None:
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,memory.used,utilization.gpu", "--format=csv,noheader"],
            check=True,
            text=True,
            capture_output=True,
        )
        emit({"available": True, "gpus": [line.strip() for line in result.stdout.splitlines() if line.strip()]})
    except Exception as exc:
        emit({"available": False, "message": str(exc), "gpus": []})


def transcribe(args: argparse.Namespace) -> None:
    if args.model_dir:
        item = next((model for model in MODEL_CATALOG if model["id"] == args.model_id), None)
        if item is None:
            raise ValueError(f"未知模型：{args.model_id}")
        selected_model = Path(args.model_dir).expanduser().resolve() / item["dir"]
    else:
        selected_model = Path(args.model)

    def progress(event: str, data: dict[str, object]) -> None:
        if args.jsonl:
            emit({"event": event, **data})

    result = process_video(
        video=Path(args.video),
        output_dir=Path(args.output_dir) if args.output_dir else None,
        model=str(selected_model),
        language=args.language,
        device=args.device,
        compute_type=args.compute_type,
        segment_seconds=args.segment_seconds,
        allow_download=False,
        progress=progress if args.jsonl else None,
    )
    emit(
        {
            "event": "complete",
            "outputDir": str(result.output_dir),
            "srt": str(result.srt),
            "transcriptMd": str(result.transcript_md),
            "tutorialMd": str(result.tutorial_md),
            "implementationPlanMd": str(result.implementation_plan_md),
            "subtitleCount": result.subtitle_count,
            "durationSeconds": result.duration_seconds,
            "audioSegments": [str(path) for path in result.audio_segments],
        }
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AI Audio local engine")
    parser.add_argument("--version", action="store_true", help="Print engine version and exit")
    subparsers = parser.add_subparsers(dest="command")

    catalog_parser = subparsers.add_parser("model-catalog")
    catalog_parser.add_argument("--model-dir")
    catalog_parser.set_defaults(func=catalog)

    status_parser = subparsers.add_parser("model-status")
    status_parser.add_argument("--model-dir")
    status_parser.set_defaults(func=model_status)

    download_parser = subparsers.add_parser("download-model")
    download_parser.add_argument("--model-dir", required=True)
    download_parser.add_argument("--model-id", default="large-v3", choices=[item["id"] for item in MODEL_CATALOG])
    download_parser.set_defaults(func=download_model)

    probe_parser = subparsers.add_parser("probe")
    probe_parser.add_argument("video")
    probe_parser.set_defaults(func=probe)

    gpu_parser = subparsers.add_parser("gpu-status")
    gpu_parser.set_defaults(func=gpu_status)

    transcribe_parser = subparsers.add_parser("transcribe")
    transcribe_parser.add_argument("video")
    transcribe_parser.add_argument("--output-dir")
    transcribe_parser.add_argument("--model", default=str(REPO_ROOT / DEFAULT_MODEL))
    transcribe_parser.add_argument("--model-dir")
    transcribe_parser.add_argument("--model-id", default="large-v3")
    transcribe_parser.add_argument("--language", default="zh")
    transcribe_parser.add_argument("--device", default="cuda")
    transcribe_parser.add_argument("--compute-type", default="float16")
    transcribe_parser.add_argument("--segment-seconds", type=int, default=600)
    transcribe_parser.add_argument("--jsonl", action="store_true")
    transcribe_parser.set_defaults(func=transcribe)

    return parser


def main() -> None:
    ffmpeg_dir = os.environ.get("AI_AUDIO_FFMPEG_DIR")
    if ffmpeg_dir:
        os.environ["PATH"] = ffmpeg_dir + os.pathsep + os.environ.get("PATH", "")
    cuda_dir = os.environ.get("AI_AUDIO_CUDA_DIR")
    if cuda_dir:
        os.environ["PATH"] = cuda_dir + os.pathsep + os.environ.get("PATH", "")
        if os.name == "nt" and hasattr(os, "add_dll_directory"):
            os.add_dll_directory(cuda_dir)

    parser = build_parser()
    args = parser.parse_args()
    if args.version:
        print(ENGINE_VERSION)
        return
    if not hasattr(args, "func"):
        parser.print_help()
        return
    if args.command in {"probe", "transcribe"} and shutil.which("ffprobe") is None:
        raise RuntimeError("未找到 ffprobe。请确认便携运行时包含 ffmpeg/ffprobe。")
    args.func(args)


if __name__ == "__main__":
    main()
