#!/bin/bash
set -euo pipefail

BS=${BS:-http://localhost:2224}
PROJECT='C:\builds\hello-rust'
DIR=$(cd "$(dirname "$0")" && pwd)

echo "[hello-rust] waiting for build server..."
until curl -fsS "$BS/health" >/dev/null 2>&1; do sleep 2; done

echo "[hello-rust] uploading sources..."
for f in Cargo.toml src/main.rs; do
  curl -fsS -X POST "$BS/upload?dest=${PROJECT}\\${f//\//\\}" \
    --data-binary "@$DIR/$f" >/dev/null
done

echo "[hello-rust] building..."
curl -fsS -X POST "$BS/exec" \
  -H 'Content-Type: application/json' \
  -d "{\"cmd\": \"cd ${PROJECT} ; cargo build --release\"}" | tee /tmp/leanwin-rust.json

echo
echo "[hello-rust] downloading artifact..."
curl -fsS -o "$DIR/hello-rust.exe" \
  "$BS/download?path=${PROJECT}\\target\\release\\hello-rust.exe"

echo "[hello-rust] done → $DIR/hello-rust.exe"
file "$DIR/hello-rust.exe" 2>/dev/null || true
