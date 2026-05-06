use std::process::Command;

#[tauri::command]
fn engine_version() -> Result<String, String> {
    let output = Command::new("python")
        .arg("../../apps/local-engine/engine_cli.py")
        .arg("--version")
        .output()
        .map_err(|err| err.to_string())?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).trim().to_string())
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![engine_version])
        .run(tauri::generate_context!())
        .expect("error while running AI Audio client");
}

