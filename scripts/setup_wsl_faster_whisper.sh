#!/usr/bin/env bash
set -euo pipefail

VENV_DIR="${VENV_DIR:-$HOME/venvs/faster-whisper}"
MODEL_REPO="${MODEL_REPO:-Systran/faster-whisper-large-v3}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="${MODEL_DIR:-$PROJECT_DIR/models/faster-whisper-large-v3}"
DOWNLOAD_MODEL="${DOWNLOAD_MODEL:-0}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required."
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required. Install it in WSL with: sudo apt update && sudo apt install -y ffmpeg"
  exit 1
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi was not found in WSL. Check WSL GPU support before continuing."
  exit 1
fi

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip setuptools wheel
python -m pip install --upgrade \
  "faster-whisper" \
  "gradio" \
  "huggingface_hub[cli]" \
  "nvidia-cublas-cu12" \
  "nvidia-cudnn-cu12==9.*"

SITE_PACKAGES="$(python - <<'PY'
import site
print(site.getsitepackages()[0])
PY
)"

CUBLAS_LIB="$SITE_PACKAGES/nvidia/cublas/lib"
CUDNN_LIB="$SITE_PACKAGES/nvidia/cudnn/lib"

cat > "$VENV_DIR/env.sh" <<EOF
#!/usr/bin/env bash
source "$VENV_DIR/bin/activate"
export LD_LIBRARY_PATH="$CUBLAS_LIB:$CUDNN_LIB:\${LD_LIBRARY_PATH:-}"
export HF_HOME="\${HF_HOME:-$HOME/.cache/huggingface}"
export FASTER_WHISPER_MODEL_DIR="$MODEL_DIR"
EOF

chmod +x "$VENV_DIR/env.sh"

if [ "$DOWNLOAD_MODEL" = "1" ]; then
  mkdir -p "$MODEL_DIR"
  huggingface-cli download "$MODEL_REPO" \
    --local-dir "$MODEL_DIR" \
    --local-dir-use-symlinks False
fi

source "$VENV_DIR/env.sh"
python - <<'PY'
from faster_whisper import WhisperModel

print("faster-whisper import OK")
print("CUDA test will be performed during model loading/transcription.")
PY

nvidia-smi

echo
echo "Setup complete."
echo "Activate with: source $VENV_DIR/env.sh"
echo "Default manual model download:"
echo "  huggingface-cli download $MODEL_REPO --local-dir $MODEL_DIR --local-dir-use-symlinks False"
