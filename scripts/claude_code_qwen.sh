#!/usr/bin/env bash
# Launch Claude Code against the Qwen3.8-27B pod instead of Anthropic.
# vLLM serves the Anthropic Messages API natively, so no proxy is needed.
# Usage:  QWEN_API_KEY=... ./scripts/claude_code_qwen.sh [claude args...]
#   e.g.  ./scripts/claude_code_qwen.sh              # interactive, in the current directory
#         ./scripts/claude_code_qwen.sh -p "list the files here and summarize the project"
set -euo pipefail
POD_ID="${POD_ID:-f2yfyf7oaffpx6}"
BASE="${QWEN_ANTHROPIC_BASE_URL:-https://${POD_ID}-8000.proxy.runpod.net}"   # NO /v1 — Claude Code appends /v1/messages
MODEL="${QWEN_MODEL:-qwen3.8-27b}"
: "${QWEN_API_KEY:?set QWEN_API_KEY (the VLLM_API_KEY of the pod)}"

export ANTHROPIC_BASE_URL="$BASE"
export ANTHROPIC_AUTH_TOKEN="$QWEN_API_KEY"
export ANTHROPIC_API_KEY=""                       # make sure a real Anthropic key does not take precedence
export ANTHROPIC_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL"
export ANTHROPIC_SMALL_FAST_MODEL="$MODEL"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1   # no telemetry / update pings to Anthropic
export DISABLE_PROMPT_CACHING=1                     # vLLM ignores Anthropic cache_control anyway
export CLAUDE_CODE_EFFORT_LEVEL="${QWEN_EFFORT:-medium}"   # Claude Code sends effort=high by default; Qwen only knows low/medium/xhigh

echo "→ Claude Code on $MODEL via $BASE" >&2
exec claude --model "$MODEL" "$@"
