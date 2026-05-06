param(
  [string]$PythonVersion = "3.11.9",
  [string]$PythonUrl = "",
  [string]$FfmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
  [string]$CudaDllZipUrl = "",
  [switch]$SkipRuntimeDownload
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ClientDir = Join-Path $RepoRoot "apps\windows-client"
$TauriDir = Join-Path $ClientDir "src-tauri"
$PortableRoot = Join-Path $RepoRoot "dist-portable\AI-Audio-Windows-Portable"
$CacheDir = Join-Path $RepoRoot ".cache\portable"
$PythonDir = Join-Path $PortableRoot "python"
$FfmpegDir = Join-Path $PortableRoot "ffmpeg"
$CudaDir = Join-Path $PortableRoot "cuda"

if (-not $PythonUrl) {
  $PythonZipName = "python-$PythonVersion-embed-amd64.zip"
  $PythonUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonZipName"
}

function New-CleanDirectory([string]$Path) {
  if (Test-Path $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Download-File([string]$Url, [string]$Target) {
  if (Test-Path $Target) {
    return
  }
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $Target
}

Write-Host "Building frontend"
npm --workspace apps/windows-client run build

Write-Host "Building Tauri executable"
cargo build --release --manifest-path (Join-Path $TauriDir "Cargo.toml")

New-CleanDirectory $PortableRoot
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PortableRoot "engine") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PortableRoot "scripts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PortableRoot "models") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PortableRoot "output") | Out-Null

$ExeSource = Join-Path $TauriDir "target\release\ai-audio-windows-client.exe"
if (-not (Test-Path $ExeSource)) {
  throw "Tauri executable not found: $ExeSource"
}
Copy-Item $ExeSource (Join-Path $PortableRoot "AI Audio.exe")
Copy-Item (Join-Path $RepoRoot "apps\local-engine\engine_cli.py") (Join-Path $PortableRoot "engine\engine_cli.py")
Copy-Item (Join-Path $RepoRoot "scripts\transcribe_course.py") (Join-Path $PortableRoot "scripts\transcribe_course.py")

if (-not $SkipRuntimeDownload) {
  $PythonZip = Join-Path $CacheDir (Split-Path $PythonUrl -Leaf)
  Download-File $PythonUrl $PythonZip
  Expand-Archive -LiteralPath $PythonZip -DestinationPath $PythonDir -Force

  $PthFile = Get-ChildItem -Path $PythonDir -Filter "python*._pth" | Select-Object -First 1
  if ($PthFile) {
    $PthContent = Get-Content -LiteralPath $PthFile.FullName
    $PthContent = $PthContent | ForEach-Object {
      if ($_ -eq "#import site") { "import site" } else { $_ }
    }
    Set-Content -LiteralPath $PthFile.FullName -Value $PthContent -Encoding ASCII
  }

  $GetPip = Join-Path $CacheDir "get-pip.py"
  Download-File "https://bootstrap.pypa.io/get-pip.py" $GetPip
  & (Join-Path $PythonDir "python.exe") $GetPip
  & (Join-Path $PythonDir "python.exe") -m pip install --upgrade pip
  & (Join-Path $PythonDir "python.exe") -m pip install faster-whisper "huggingface_hub[cli]"

  $FfmpegZip = Join-Path $CacheDir "ffmpeg-release-essentials.zip"
  $FfmpegExtract = Join-Path $CacheDir "ffmpeg"
  Download-File $FfmpegUrl $FfmpegZip
  if (Test-Path $FfmpegExtract) {
    Remove-Item -LiteralPath $FfmpegExtract -Recurse -Force
  }
  Expand-Archive -LiteralPath $FfmpegZip -DestinationPath $FfmpegExtract -Force
  $BinDir = Get-ChildItem -Path $FfmpegExtract -Recurse -Directory -Filter "bin" | Select-Object -First 1
  if (-not $BinDir) {
    throw "ffmpeg bin directory not found after extracting $FfmpegZip"
  }
  New-Item -ItemType Directory -Force -Path (Join-Path $FfmpegDir "bin") | Out-Null
  Copy-Item (Join-Path $BinDir.FullName "ffmpeg.exe") (Join-Path $FfmpegDir "bin\ffmpeg.exe")
  Copy-Item (Join-Path $BinDir.FullName "ffprobe.exe") (Join-Path $FfmpegDir "bin\ffprobe.exe")

  New-Item -ItemType Directory -Force -Path (Join-Path $CudaDir "bin") | Out-Null
  if ($CudaDllZipUrl) {
    $CudaZip = Join-Path $CacheDir (Split-Path $CudaDllZipUrl -Leaf)
    $CudaExtract = Join-Path $CacheDir "cuda-dlls"
    Download-File $CudaDllZipUrl $CudaZip
    if (Test-Path $CudaExtract) {
      Remove-Item -LiteralPath $CudaExtract -Recurse -Force
    }
    Expand-Archive -LiteralPath $CudaZip -DestinationPath $CudaExtract -Force
    Get-ChildItem -Path $CudaExtract -Recurse -Filter "*.dll" | ForEach-Object {
      Copy-Item $_.FullName (Join-Path $CudaDir "bin")
    }
  }
}

$Readme = @"
# AI Audio Windows Portable

双击 `AI Audio.exe` 启动。

首次使用请进入“模型管理”：

1. 选择或保留默认模型目录 `models\`。
2. 下载一个 ASR 模型，或手动把模型文件放入对应目录。
3. 回到“转写任务”选择视频并开始处理。

模型文件不会随便携包内置，避免包体过大。
"@
Set-Content -LiteralPath (Join-Path $PortableRoot "README.txt") -Value $Readme -Encoding UTF8

Write-Host "Portable package created:"
Write-Host $PortableRoot
