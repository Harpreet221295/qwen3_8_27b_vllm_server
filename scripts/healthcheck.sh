#!/usr/bin/env bash
# Usage: QWEN_BASE_URL=https://<pod>-8000.proxy.runpod.net/v1 QWEN_API_KEY=... ./scripts/healthcheck.sh
set -euo pipefail
BASE="${QWEN_BASE_URL:-http://localhost:8000/v1}"
KEY="${QWEN_API_KEY:-none}"
ROOT="${BASE%/v1}"
echo "health: $(curl -s -o /dev/null -w '%{http_code}' "$ROOT/health")"
echo "models:"; curl -s -H "Authorization: Bearer $KEY" "$BASE/models" | python3 -m json.tool | head -20
echo "chat:"
curl -s "$BASE/chat/completions" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"Say hi in 5 words."}],
       "max_tokens":64,"chat_template_kwargs":{"enable_thinking":false}}' | python3 -m json.tool
