$ErrorActionPreference = "Stop"

$ProjectDir = "E:\AI-PROJECT\ai-audio"
$Port = 7860
$Url = "http://127.0.0.1:$Port"

Write-Host "AI video transcription Web UI"
Write-Host "Project: $ProjectDir"
Write-Host "URL: $Url"
Write-Host ""

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
    $args = @(
        "-d", "Ubuntu-22.04",
        "--",
        "bash", "-lc",
        "cd /mnt/e/AI-PROJECT/ai-audio && mkdir -p logs && source ~/venvs/faster-whisper/env.sh && python scripts/app.py --host 127.0.0.1 --port $Port > logs/webui.log 2>&1"
    )
    Start-Process -WindowStyle Hidden -FilePath "wsl.exe" -ArgumentList $args

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($listener) {
            $ready = $true
            break
        }
    }

    if (-not $ready) {
        Write-Host "Web UI did not become ready. Check logs\webui.log"
        exit 1
    }
}

Start-Process $Url | Out-Null
Write-Host "Web UI is running: $Url"
