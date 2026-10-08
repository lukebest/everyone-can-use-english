#!/usr/bin/env bash
# Build whisper.cpp and download the English base model used by POST /v1/transcribe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d whisper.cpp/.git ]]; then
  git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git whisper.cpp
fi

cmake -B whisper.cpp/build -S whisper.cpp -DCMAKE_BUILD_TYPE=Release
cmake --build whisper.cpp/build -j --target whisper-cli

if [[ ! -f whisper.cpp/models/ggml-base.en.bin ]]; then
  bash whisper.cpp/models/download-ggml-model.sh base.en
fi

BIN=""
for candidate in whisper.cpp/build/bin/whisper-cli whisper.cpp/build/bin/main whisper.cpp/main; do
  if [[ -x "$candidate" ]]; then
    BIN="$candidate"
    break
  fi
done

echo "WHISPER_BIN=${BIN:-whisper.cpp/build/bin/whisper-cli}"
echo "WHISPER_MODEL=whisper.cpp/models/ggml-base.en.bin"
