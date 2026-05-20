#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
for k in "$DIR/leanwin_key" "/tmp/leanwin_key" "$HOME/.ssh/leanwin_key"; do
  [ -f "$k" ] && KEY="$k" && break
done
: ${KEY:="$DIR/leanwin_key"}

SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2223)

if [ $# -eq 0 ]; then
  exec ssh "${SSH_OPTS[@]}" builder@localhost
fi

CMD=$(echo "$*" | sed 's/&&/;/g; s/||/;/g')
ENCODED=$(echo "$CMD" | iconv -f UTF-8 -t UTF-16LE 2>/dev/null | base64 -w0)
exec ssh "${SSH_OPTS[@]}" builder@localhost "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $ENCODED"
