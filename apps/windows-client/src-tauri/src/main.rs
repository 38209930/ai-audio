use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Serialize)]
struct CommandResult {
    stdout: String,
    stderr: String,
}

#[derive(Debug, Serialize)]
struct TranscribeResult {
    result: Value,
    log: Vec<Value>,
    stderr: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TranscribeOptions {
    video: String,
    model_dir: String,
    model_id: String,
    language: String,
    segment_seconds: u32,
    device: String,
    compute_type: String,
}

fn dev_repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .and_then(Path::parent)
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."))
}

fn runtime_root() -> Result<PathBuf, String> {
    if let Ok(root) = std::env::var("AI_AUDIO_PORTABLE_ROOT") {
        return Ok(PathBuf::from(root));
    }

    if cfg!(debug_assertions) {
        return Ok(dev_repo_root());
    }

    let exe = std::env::current_exe().map_err(|err| err.to_string())?;
    Ok(exe
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from(".")))
}

fn python_path(root: &Path) -> String {
    let embedded = root.join("python").join("python.exe");
    if embedded.is_file() {
        embedded.to_string_lossy().to_string()
    } else {
        "python".to_string()
    }
}

fn engine_path(root: &Path) -> PathBuf {
    let bundled = root.join("engine").join("engine_cli.py");
    if bundled.is_file() {
        bundled
    } else {
        dev_repo_root().join("apps").join("local-engine").join("engine_cli.py")
    }
}

fn build_engine_command(root: &Path) -> Command {
    let mut command = Command::new(python_path(root));
    command.arg(engine_path(root));
    command.current_dir(root);
    let ffmpeg_dir = root.join("ffmpeg").join("bin");
    if ffmpeg_dir.is_dir() {
        command.env("AI_AUDIO_FFMPEG_DIR", ffmpeg_dir);
    }
    let cuda_dir = root.join("cuda").join("bin");
    if cuda_dir.is_dir() {
        command.env("AI_AUDIO_CUDA_DIR", cuda_dir);
    }
    command
}

fn run_engine(args: &[&str]) -> Result<CommandResult, String> {
    let root = runtime_root()?;
    let output = build_engine_command(&root)
        .args(args)
        .output()
        .map_err(|err| err.to_string())?;

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if output.status.success() {
        Ok(CommandResult { stdout, stderr })
    } else {
        Err(if stderr.is_empty() { stdout } else { stderr })
    }
}

fn run_engine_json(args: &[&str]) -> Result<Value, String> {
    let result = run_engine(args)?;
    serde_json::from_str(&result.stdout).map_err(|err| format!("引擎返回内容无法解析：{err}\n{}", result.stdout))
}

#[tauri::command]
fn engine_version() -> Result<String, String> {
    Ok(run_engine(&["--version"])?.stdout)
}

#[tauri::command]
fn default_model_dir() -> Result<String, String> {
    Ok(runtime_root()?.join("models").to_string_lossy().to_string())
}

#[tauri::command]
fn model_status(model_dir: String) -> Result<Value, String> {
    run_engine_json(&["model-status", "--model-dir", &model_dir])
}

#[tauri::command]
fn model_catalog(model_dir: String) -> Result<Value, String> {
    run_engine_json(&["model-catalog", "--model-dir", &model_dir])
}

#[tauri::command]
fn download_model(model_dir: String, model_id: String) -> Result<Vec<Value>, String> {
    let root = runtime_root()?;
    let output = build_engine_command(&root)
        .args(["download-model", "--model-dir", &model_dir, "--model-id", &model_id])
        .output()
        .map_err(|err| err.to_string())?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !output.status.success() {
        return Err(if stderr.is_empty() { stdout.trim().to_string() } else { stderr });
    }
    Ok(stdout
        .lines()
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .collect())
}

#[tauri::command]
fn probe_video(video: String) -> Result<Value, String> {
    run_engine_json(&["probe", &video])
}

#[tauri::command]
fn gpu_status() -> Result<Value, String> {
    run_engine_json(&["gpu-status"])
}

#[tauri::command]
fn transcribe_video(options: TranscribeOptions) -> Result<TranscribeResult, String> {
    let root = runtime_root()?;
    let output = build_engine_command(&root)
        .args([
            "transcribe",
            &options.video,
            "--model-dir",
            &options.model_dir,
            "--model-id",
            &options.model_id,
            "--language",
            &options.language,
            "--segment-seconds",
            &options.segment_seconds.to_string(),
            "--device",
            &options.device,
            "--compute-type",
            &options.compute_type,
            "--jsonl",
        ])
        .output()
        .map_err(|err| err.to_string())?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !output.status.success() {
        return Err(if stderr.is_empty() { stdout.trim().to_string() } else { stderr });
    }

    let log: Vec<Value> = stdout
        .lines()
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .collect();
    let result = log
        .iter()
        .rev()
        .find(|item| item.get("event").and_then(Value::as_str) == Some("complete"))
        .cloned()
        .ok_or_else(|| "转写完成，但没有收到结果信息。".to_string())?;

    Ok(TranscribeResult { result, log, stderr })
}

#[tauri::command]
fn open_output_dir(path: String) -> Result<(), String> {
    Command::new("explorer")
        .arg(path)
        .spawn()
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            engine_version,
            default_model_dir,
            model_status,
            model_catalog,
            download_model,
            probe_video,
            gpu_status,
            transcribe_video,
            open_output_dir,
        ])
        .run(tauri::generate_context!())
        .expect("error while running AI Audio client");
}
