#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from transcribe_course import DEFAULT_MODEL, process_video  # noqa: E402

ENGINE_VERSION = "0.1.0"


def transcribe(args: argparse.Namespace) -> None:
    result = process_video(
        video=Path(args.video),
        output_dir=Path(args.output_dir) if args.output_dir else None,
        model=args.model,
        language=args.language,
        device=args.device,
        compute_type=args.compute_type,
        segment_seconds=args.segment_seconds,
        allow_download=False,
    )
    print(
        json.dumps(
            {
                "outputDir": str(result.output_dir),
                "srt": str(result.srt),
                "transcriptMd": str(result.transcript_md),
                "tutorialMd": str(result.tutorial_md),
                "implementationPlanMd": str(result.implementation_plan_md),
                "subtitleCount": result.subtitle_count,
                "durationSeconds": result.duration_seconds,
            },
            ensure_ascii=False,
        )
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AI Audio local engine")
    parser.add_argument("--version", action="store_true", help="Print engine version and exit")
    subparsers = parser.add_subparsers(dest="command")

    transcribe_parser = subparsers.add_parser("transcribe")
    transcribe_parser.add_argument("video")
    transcribe_parser.add_argument("--output-dir")
    transcribe_parser.add_argument("--model", default=str(REPO_ROOT / DEFAULT_MODEL))
    transcribe_parser.add_argument("--language", default="zh")
    transcribe_parser.add_argument("--device", default="cuda")
    transcribe_parser.add_argument("--compute-type", default="float16")
    transcribe_parser.add_argument("--segment-seconds", type=int, default=600)
    transcribe_parser.set_defaults(func=transcribe)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    if args.version:
        print(ENGINE_VERSION)
        return
    if not hasattr(args, "func"):
        parser.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()

