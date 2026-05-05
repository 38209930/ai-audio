#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import gradio as gr
from huggingface_hub import snapshot_download

PROJECT_DIR = Path(__file__).resolve().parents[1]
if str(PROJECT_DIR / "scripts") not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR / "scripts"))

from transcribe_course import (  # noqa: E402
    DEFAULT_MODEL,
    REQUIRED_MODEL_FILES,
    format_md_time,
    probe_duration,
    process_video,
    safe_stem,
)


MODEL_REPO = "Systran/faster-whisper-large-v3"
HF_MIRROR = "https://hf-mirror.com"
HF_ORIGINAL = "https://huggingface.co"
MODEL_DIR = PROJECT_DIR / DEFAULT_MODEL
UPLOAD_DIR = PROJECT_DIR / "input" / "uploads"
SUPPORTED_EXTENSIONS = {".mp4", ".mkv", ".mov", ".webm", ".avi", ".flv"}


def missing_model_files(model_dir: Path = MODEL_DIR) -> list[str]:
    return [name for name in REQUIRED_MODEL_FILES if not (model_dir / name).is_file()]


def model_status() -> str:
    missing = missing_model_files()
    if not missing:
        total_size = sum((MODEL_DIR / name).stat().st_size for name in REQUIRED_MODEL_FILES)
        return (
            "### 模型状态\n"
            f"- 状态：已就绪\n"
            f"- 目录：`{MODEL_DIR}`\n"
            f"- 文件数：{len(REQUIRED_MODEL_FILES)}\n"
            f"- 大小：{total_size / 1024 / 1024 / 1024:.2f} GB"
        )

    missing_text = "\n".join(f"- `{name}`" for name in missing)
    return (
        "### 模型状态\n"
        "- 状态：缺少文件\n"
        f"- 目录：`{MODEL_DIR}`\n"
        "- 缺失：\n"
        f"{missing_text}\n\n"
        f"镜像页：{HF_MIRROR}/{MODEL_REPO}/tree/main\n"
        f"备用页：{HF_ORIGINAL}/{MODEL_REPO}"
    )


def download_model(progress: gr.Progress = gr.Progress()) -> str:
    missing = missing_model_files()
    if not missing:
        return model_status()

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    os.environ["HF_ENDPOINT"] = HF_MIRROR
    progress(0.05, desc="准备从 hf-mirror.com 下载模型")
    try:
        snapshot_download(
            repo_id=MODEL_REPO,
            endpoint=HF_MIRROR,
            local_dir=MODEL_DIR,
            allow_patterns=list(REQUIRED_MODEL_FILES),
            max_workers=4,
        )
    except Exception as exc:
        raise gr.Error(
            "模型下载失败。请检查网络，或手动下载模型文件到 "
            f"{MODEL_DIR}。\n镜像页：{HF_MIRROR}/{MODEL_REPO}/tree/main\n"
            f"备用页：{HF_ORIGINAL}/{MODEL_REPO}\n错误：{exc}"
        ) from exc

    progress(1.0, desc="模型下载完成")
    return model_status()


def gpu_status() -> str:
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,memory.used,utilization.gpu", "--format=csv,noheader"],
            check=True,
            text=True,
            capture_output=True,
        )
        return "### GPU 状态\n" + "\n".join(f"- {line}" for line in result.stdout.strip().splitlines())
    except Exception as exc:
        return f"### GPU 状态\n- 无法读取 GPU：{exc}"


def file_info(video_path: str | None) -> str:
    if not video_path:
        return "### 视频信息\n- 尚未上传视频"

    path = Path(video_path)
    if not path.exists():
        return "### 视频信息\n- 文件不存在"

    ext = path.suffix.lower()
    size_mb = path.stat().st_size / 1024 / 1024
    lines = [
        "### 视频信息",
        f"- 文件名：`{path.name}`",
        f"- 格式：`{ext or '未知'}`",
        f"- 大小：{size_mb:.2f} MB",
    ]
    try:
        duration = probe_duration(path)
        lines.append(f"- 时长：{format_md_time(duration)}")
        if duration > 7200:
            lines.append("- 建议：超过 2 小时，建议按章节拆分后处理。")
        elif duration > 3600:
            lines.append("- 建议：可直接处理，但请保持电脑空闲，避免休眠。")
        else:
            lines.append("- 建议：可直接处理，脚本会自动切成 10 分钟以内音频。")
    except Exception as exc:
        lines.append(f"- 时长读取失败：{exc}")
    return "\n".join(lines)


def copy_upload(video_path: str) -> Path:
    source = Path(video_path)
    if not source.exists():
        raise gr.Error("上传的视频文件不存在。")

    ext = source.suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise gr.Error(f"不支持的视频格式：{ext}。请上传 mp4/mkv/mov/webm/avi/flv。")

    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    target_name = f"{safe_stem(source)}{ext}"
    target = UPLOAD_DIR / target_name
    counter = 1
    while target.exists():
        target = UPLOAD_DIR / f"{safe_stem(source)}_{counter}{ext}"
        counter += 1
    shutil.copy2(source, target)
    return target


def apply_stable_mode(stable: bool) -> tuple[int, str]:
    if stable:
        return 300, "int8_float16"
    return 600, "float16"


def transcribe_from_ui(
    video_path: str | None,
    language: str,
    segment_seconds: int,
    device: str,
    compute_type: str,
    auto_download: bool,
    progress: gr.Progress = gr.Progress(),
) -> tuple[str, str, str, str, str]:
    if not video_path:
        raise gr.Error("请先上传一个视频文件。")

    segment_seconds = int(segment_seconds)
    if segment_seconds <= 0 or segment_seconds > 600:
        raise gr.Error("切片长度必须在 1 到 600 秒之间。")

    progress(0.02, desc="检查本地模型")
    if missing_model_files():
        if auto_download:
            download_model(progress)
        else:
            raise gr.Error("本地模型文件不完整。请点击“检查/下载模型”，或开启自动下载。")

    progress(0.08, desc="保存上传文件")
    local_video = copy_upload(video_path)
    output_dir = PROJECT_DIR / "output" / safe_stem(local_video)

    progress(0.12, desc="开始提取音频、切片并转写")
    try:
        result = process_video(
            video=local_video,
            output_dir=output_dir,
            model=str(MODEL_DIR),
            language=language.strip() or None,
            device=device,
            compute_type=compute_type,
            segment_seconds=segment_seconds,
            allow_download=False,
        )
    except Exception as exc:
        raise gr.Error(f"转写失败：{exc}") from exc

    progress(1.0, desc="处理完成")
    status = (
        "### 处理完成\n"
        f"- 输出目录：`{result.output_dir}`\n"
        f"- 字幕条数：{result.subtitle_count}\n"
        f"- 估算时长：{format_md_time(result.duration_seconds)}\n"
        f"- 音频切片数：{len(result.audio_segments)}"
    )
    return (
        status,
        str(result.srt),
        str(result.transcript_md),
        str(result.tutorial_md),
        str(result.implementation_plan_md),
    )


def build_app() -> gr.Blocks:
    with gr.Blocks(title="AI 视频转字幕与教程整理") as demo:
        gr.Markdown(
            "# AI 视频转字幕与教程整理\n"
            "上传一个课程视频，自动检查/下载本地 faster-whisper 模型，生成 SRT 字幕、Markdown 时间轴文稿、详细教程和实施方案。"
        )

        with gr.Row():
            model_box = gr.Markdown(model_status())
            gpu_box = gr.Markdown(gpu_status())

        with gr.Row():
            check_model_btn = gr.Button("检查模型", variant="secondary")
            download_model_btn = gr.Button("检查/下载模型", variant="primary")
            refresh_gpu_btn = gr.Button("刷新 GPU 状态", variant="secondary")

        with gr.Row():
            with gr.Column(scale=2):
                video = gr.File(
                    label="上传视频",
                    file_count="single",
                    file_types=[".mp4", ".mkv", ".mov", ".webm", ".avi", ".flv"],
                    type="filepath",
                )
                video_info = gr.Markdown(file_info(None))
            with gr.Column(scale=1):
                language = gr.Textbox(value="zh", label="语言代码", info="中文用 zh；留空则自动检测。")
                segment_seconds = gr.Slider(60, 600, value=600, step=60, label="音频切片秒数")
                device = gr.Dropdown(["cuda", "cpu", "auto"], value="cuda", label="设备")
                compute_type = gr.Dropdown(
                    ["float16", "int8_float16", "int8", "float32"],
                    value="float16",
                    label="计算精度",
                )
                stable_mode = gr.Checkbox(False, label="稳定模式", info="切片 300 秒，并使用 int8_float16。")
                auto_download = gr.Checkbox(True, label="缺模型时自动下载", info="默认从 hf-mirror.com 下载。")

        start_btn = gr.Button("开始转写并生成文档", variant="primary", size="lg")
        status = gr.Markdown("### 状态\n- 等待上传视频")

        with gr.Row():
            srt_file = gr.File(label="SRT 字幕")
            transcript_file = gr.File(label="MD 时间轴文稿")
        with gr.Row():
            tutorial_file = gr.File(label="详细教程")
            plan_file = gr.File(label="实施方案")

        check_model_btn.click(model_status, outputs=model_box)
        download_model_btn.click(download_model, outputs=model_box)
        refresh_gpu_btn.click(gpu_status, outputs=gpu_box)
        video.change(file_info, inputs=video, outputs=video_info)
        stable_mode.change(apply_stable_mode, inputs=stable_mode, outputs=[segment_seconds, compute_type])
        start_btn.click(
            transcribe_from_ui,
            inputs=[video, language, segment_seconds, device, compute_type, auto_download],
            outputs=[status, srt_file, transcript_file, tutorial_file, plan_file],
        )

    return demo


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Launch the local transcription Web UI.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7860)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    app = build_app()
    app.queue(default_concurrency_limit=1).launch(
        server_name=args.host,
        server_port=args.port,
        share=False,
        inbrowser=False,
    )


if __name__ == "__main__":
    main()
