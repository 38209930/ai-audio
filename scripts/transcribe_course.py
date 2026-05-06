#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

DEFAULT_MODEL = "models/faster-whisper-large-v3"
REQUIRED_MODEL_FILES = (
    "config.json",
    "model.bin",
    "preprocessor_config.json",
    "tokenizer.json",
    "vocabulary.json",
)


@dataclass
class TranscriptSegment:
    index: int
    start: float
    end: float
    text: str


@dataclass
class ProcessResult:
    output_dir: Path
    full_audio: Path
    audio_segments: list[Path]
    srt: Path
    transcript_md: Path
    tutorial_md: Path
    implementation_plan_md: Path
    subtitle_count: int
    duration_seconds: float


def run(command: list[str]) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, check=True)


def safe_stem(path: Path) -> str:
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", path.stem).strip("._-")
    return stem or "course"


def looks_like_local_path(value: str) -> bool:
    return (
        value.startswith("~")
        or value.startswith(".")
        or "/" in value
        or "\\" in value
    )


def resolve_model_argument(model: str, allow_download: bool) -> str:
    if looks_like_local_path(model):
        model_path = Path(model).expanduser()
        missing = [name for name in REQUIRED_MODEL_FILES if not (model_path / name).is_file()]
        if missing:
            missing_text = ", ".join(missing)
            raise FileNotFoundError(
                f"Local model directory is incomplete: {model_path}\n"
                f"Missing files: {missing_text}\n"
                "Download Systran/faster-whisper-large-v3 manually and keep all required files in this directory."
            )
        return str(model_path.resolve())

    if not allow_download:
        raise ValueError(
            f"Model '{model}' is a remote model name and would trigger automatic download.\n"
            "Use --model ~/models/faster-whisper-large-v3 after downloading the model manually, "
            "or pass --allow-download if online download is intentional."
        )

    return model


def format_srt_time(seconds: float) -> str:
    milliseconds = int(round(seconds * 1000))
    hours, remainder = divmod(milliseconds, 3_600_000)
    minutes, remainder = divmod(remainder, 60_000)
    secs, millis = divmod(remainder, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def format_md_time(seconds: float) -> str:
    total = int(round(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def probe_duration(path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    return float(result.stdout.strip())


def extract_audio(video: Path, full_audio: Path) -> None:
    full_audio.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(video),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-c:a",
            "pcm_s16le",
            str(full_audio),
        ]
    )


def split_audio(full_audio: Path, segment_dir: Path, segment_seconds: int) -> list[Path]:
    segment_dir.mkdir(parents=True, exist_ok=True)
    for old_file in segment_dir.glob("part_*.wav"):
        old_file.unlink()

    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(full_audio),
            "-f",
            "segment",
            "-segment_time",
            str(segment_seconds),
            "-reset_timestamps",
            "1",
            "-c",
            "copy",
            str(segment_dir / "part_%03d.wav"),
        ]
    )
    return sorted(segment_dir.glob("part_*.wav"))


def transcribe_segments(
    model,
    audio_segments: Iterable[Path],
    segment_seconds: int,
    language: str | None,
    beam_size: int,
    vad_filter: bool,
    progress: Callable[[str, dict[str, object]], None] | None = None,
) -> list[TranscriptSegment]:
    output: list[TranscriptSegment] = []
    next_index = 1

    for segment_path in audio_segments:
        match = re.search(r"part_(\d+)\.wav$", segment_path.name)
        part_index = int(match.group(1)) if match else len(output)
        offset = part_index * segment_seconds
        if progress:
            progress(
                "transcribe_segment",
                {
                    "file": segment_path.name,
                    "partIndex": part_index,
                    "offset": offset,
                },
            )
        print(f"Transcribing {segment_path.name} at offset {format_md_time(offset)}", flush=True)

        segments, info = model.transcribe(
            str(segment_path),
            language=language,
            beam_size=beam_size,
            vad_filter=vad_filter,
            word_timestamps=False,
        )
        print(f"Detected language: {info.language} ({info.language_probability:.2f})", flush=True)

        for item in segments:
            text = " ".join(item.text.strip().split())
            if not text:
                continue
            output.append(
                TranscriptSegment(
                    index=next_index,
                    start=offset + float(item.start),
                    end=offset + float(item.end),
                    text=text,
                )
            )
            next_index += 1

    return output


def write_srt(path: Path, segments: list[TranscriptSegment]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as file:
        for segment in segments:
            file.write(f"{segment.index}\n")
            file.write(f"{format_srt_time(segment.start)} --> {format_srt_time(segment.end)}\n")
            file.write(f"{segment.text}\n\n")


def write_transcript_md(path: Path, title: str, segments: list[TranscriptSegment]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as file:
        file.write(f"# {title} Transcript\n\n")
        for segment in segments:
            file.write(
                f"- [{format_md_time(segment.start)} - {format_md_time(segment.end)}] {segment.text}\n"
            )


def group_segments(segments: list[TranscriptSegment], group_minutes: int = 10) -> list[tuple[str, list[TranscriptSegment]]]:
    if not segments:
        return []
    groups: dict[int, list[TranscriptSegment]] = {}
    group_seconds = group_minutes * 60
    for segment in segments:
        key = int(segment.start // group_seconds)
        groups.setdefault(key, []).append(segment)

    result = []
    for key in sorted(groups):
        start = key * group_seconds
        end = (key + 1) * group_seconds
        result.append((f"{format_md_time(start)} - {format_md_time(end)}", groups[key]))
    return result


def write_tutorial(path: Path, title: str, segments: list[TranscriptSegment]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    groups = group_segments(segments)
    with path.open("w", encoding="utf-8", newline="\n") as file:
        file.write(f"# {title} 详细教程\n\n")
        file.write("本文档根据字幕时间轴自动整理，保留课程顺序，适合作为二次学习和人工润色的基础稿。\n\n")
        file.write("## 课程结构\n\n")
        for label, items in groups:
            preview = " ".join(item.text for item in items[:6])
            file.write(f"- `{label}`：{preview}\n")
        file.write("\n## 分段教程\n\n")
        for label, items in groups:
            text = " ".join(item.text for item in items)
            file.write(f"### {label}\n\n")
            file.write("#### 课程内容整理\n\n")
            file.write(f"{text}\n\n")
            file.write("#### 学习提示\n\n")
            file.write("- 先对照本段时间轴回看视频，确认工具界面和操作位置。\n")
            file.write("- 将本段提到的工具、参数、素材和产物记录到自己的项目清单中。\n")
            file.write("- 如果涉及实际操作，建议完成一次小样测试后再进入下一段。\n\n")


def write_implementation_plan(path: Path, title: str, segments: list[TranscriptSegment]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    duration = segments[-1].end if segments else 0
    with path.open("w", encoding="utf-8", newline="\n") as file:
        file.write(f"# {title} 实施方案\n\n")
        file.write("## 目标\n\n")
        file.write("- 将课程内容转化为可执行项目步骤。\n")
        file.write("- 依据时间轴逐段复盘，提取工具、素材、操作和验收标准。\n\n")
        file.write("## 前置条件\n\n")
        file.write("- 已阅读 `transcripts/*.md` 时间轴文稿。\n")
        file.write("- 已准备课程中涉及的软件、账号、素材和测试项目。\n")
        file.write("- 已确认每个阶段的输出文件保存位置。\n\n")
        file.write("## 执行步骤\n\n")
        for number, (label, _) in enumerate(group_segments(segments), start=1):
            file.write(f"{number}. 复盘 `{label}` 对应课程内容，完成该阶段素材或操作产物，并记录问题。\n")
        if not segments:
            file.write("1. 转写完成后补充执行步骤。\n")
        file.write("\n## 验收标准\n\n")
        file.write("- 每个阶段都有明确输入、输出和保存路径。\n")
        file.write("- 关键参数和工具选择已记录，可重复执行。\n")
        file.write("- 最终产物可被打开、预览或导入后续软件继续处理。\n\n")
        file.write("## 风险与备选方案\n\n")
        file.write("- 若某个工具效果不稳定，保留同类替代工具和候选输出。\n")
        file.write("- 若生成结果不一致，回到参考图、提示词和素材顺序重新控制。\n")
        file.write("- 若课程中有专有名词识别错误，以视频画面和人工校对为准。\n\n")
        file.write("## 转写统计\n\n")
        file.write(f"- 字幕片段数：{len(segments)}\n")
        file.write(f"- 估算课程时长：{format_md_time(duration)}\n")


def process_video(
    video: Path,
    output_dir: Path | None = None,
    model: str = DEFAULT_MODEL,
    language: str | None = None,
    device: str = "cuda",
    compute_type: str = "float16",
    segment_seconds: int = 600,
    beam_size: int = 5,
    vad_filter: bool = True,
    skip_audio: bool = False,
    allow_download: bool = False,
    progress: Callable[[str, dict[str, object]], None] | None = None,
) -> ProcessResult:
    add_windows_nvidia_dll_dirs()
    video = video.expanduser().resolve()
    if not video.exists():
        raise FileNotFoundError(video)
    if segment_seconds <= 0 or segment_seconds > 600:
        raise ValueError("segment_seconds must be between 1 and 600.")

    if progress:
        progress("prepare", {"video": str(video)})

    title = safe_stem(video)
    output_dir = output_dir.expanduser().resolve() if output_dir else Path("output", title).resolve()
    audio_dir = output_dir / "audio"
    segment_dir = audio_dir / "segments"
    transcript_dir = output_dir / "transcripts"
    analysis_dir = output_dir / "analysis"
    full_audio = audio_dir / "full.wav"

    if not skip_audio:
        if progress:
            progress("extract_audio", {"target": str(full_audio)})
        extract_audio(video, full_audio)
        if progress:
            progress("split_audio", {"segmentSeconds": segment_seconds})
        segment_paths = split_audio(full_audio, segment_dir, segment_seconds)
    else:
        segment_paths = sorted(segment_dir.glob("part_*.wav"))

    if not segment_paths:
        raise RuntimeError(f"No audio segments found in {segment_dir}")

    validate_segment_lengths(segment_paths, segment_seconds)

    if progress:
        progress("load_model", {"model": model, "device": device, "computeType": compute_type})
    model_arg = resolve_model_argument(model, allow_download)
    from faster_whisper import WhisperModel

    whisper_model = WhisperModel(model_arg, device=device, compute_type=compute_type)
    segments = transcribe_segments(
        model=whisper_model,
        audio_segments=segment_paths,
        segment_seconds=segment_seconds,
        language=language,
        beam_size=beam_size,
        vad_filter=vad_filter,
        progress=progress,
    )

    srt_path = transcript_dir / f"{title}.srt"
    transcript_path = transcript_dir / f"{title}.md"
    tutorial_path = analysis_dir / "tutorial.md"
    plan_path = analysis_dir / "implementation_plan.md"

    if progress:
        progress("write_files", {"subtitleCount": len(segments)})
    write_srt(srt_path, segments)
    write_transcript_md(transcript_path, title, segments)
    write_tutorial(tutorial_path, title, segments)
    write_implementation_plan(plan_path, title, segments)

    duration_seconds = segments[-1].end if segments else 0.0
    return ProcessResult(
        output_dir=output_dir,
        full_audio=full_audio,
        audio_segments=segment_paths,
        srt=srt_path,
        transcript_md=transcript_path,
        tutorial_md=tutorial_path,
        implementation_plan_md=plan_path,
        subtitle_count=len(segments),
        duration_seconds=duration_seconds,
    )


def add_windows_nvidia_dll_dirs() -> None:
    if os.name != "nt" or not hasattr(os, "add_dll_directory"):
        return
    for base in map(Path, sys.path):
        nvidia_dir = base / "nvidia"
        if not nvidia_dir.is_dir():
            continue
        for candidate in nvidia_dir.glob("*/*"):
            if candidate.is_dir() and any(candidate.glob("*.dll")):
                os.add_dll_directory(str(candidate))


def validate_segment_lengths(segment_paths: list[Path], max_seconds: int) -> None:
    failures = []
    for path in segment_paths:
        duration = probe_duration(path)
        if duration > max_seconds + 1:
            failures.append((path.name, duration))
    if failures:
        details = ", ".join(f"{name}={duration:.2f}s" for name, duration in failures)
        raise RuntimeError(f"Audio segments exceed {max_seconds}s: {details}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe a course video with faster-whisper.")
    parser.add_argument("video", type=Path, help="Input video path.")
    parser.add_argument("--output-dir", type=Path, help="Output directory. Defaults to output/<video-stem>.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model name or local model directory.")
    parser.add_argument("--allow-download", action="store_true", help="Allow remote model names that may auto-download.")
    parser.add_argument("--language", default=None, help="Language code, for example zh or en. Default: auto.")
    parser.add_argument("--device", default="cuda", choices=["cuda", "cpu", "auto"], help="Whisper device.")
    parser.add_argument("--compute-type", default="float16", help="CTranslate2 compute type.")
    parser.add_argument("--segment-seconds", type=int, default=600, help="Maximum audio segment length.")
    parser.add_argument("--beam-size", type=int, default=5, help="Whisper beam size.")
    parser.add_argument("--no-vad", action="store_true", help="Disable VAD filtering.")
    parser.add_argument("--skip-audio", action="store_true", help="Reuse existing extracted/split audio.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = process_video(
        video=args.video,
        output_dir=args.output_dir,
        model=args.model,
        language=args.language,
        device=args.device,
        compute_type=args.compute_type,
        segment_seconds=args.segment_seconds,
        beam_size=args.beam_size,
        vad_filter=not args.no_vad,
        skip_audio=args.skip_audio,
        allow_download=args.allow_download,
    )

    print("Done.")
    print(f"SRT: {result.srt}")
    print(f"Markdown transcript: {result.transcript_md}")
    print(f"Tutorial draft: {result.tutorial_md}")
    print(f"Implementation plan draft: {result.implementation_plan_md}")


if __name__ == "__main__":
    main()
