#!/bin/bash
set -euo pipefail

BS=${BS:-http://localhost:2224}
PROJECT='C:\builds\hello-dotnet'
DIR=$(cd "$(dirname "$0")" && pwd)

echo "[hello-dotnet] waiting for build server..."
until curl -fsS "$BS/health" >/dev/null 2>&1; do sleep 2; done

echo "[hello-dotnet] uploading source..."
curl -fsS -X POST "$BS/upload?dest=${PROJECT}\\Program.cs" \
  --data-binary "@$DIR/Program.cs" >/dev/null

echo "[hello-dotnet] building with csc.exe (.NET Framework 4.8)..."
CSC='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
curl -fsS -X POST "$BS/exec" \
  -H 'Content-Type: application/json' \
  -d "{\"cmd\": \"cd ${PROJECT} ; \\\"${CSC}\\\" /nologo /out:hello-dotnet.exe Program.cs\"}" | tee /tmp/leanwin-dotnet.json

echo
echo "[hello-dotnet] downloading artifact..."
curl -fsS -o "$DIR/hello-dotnet.exe" \
  "$BS/download?path=${PROJECT}\\hello-dotnet.exe"

echo "[hello-dotnet] done → $DIR/hello-dotnet.exe"
file "$DIR/hello-dotnet.exe" 2>/dev/null || true
