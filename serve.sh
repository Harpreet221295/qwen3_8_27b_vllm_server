#!/usr/bin/env bash
# Start vLLM for Qwen3.8-27B. Usage: ./serve.sh [configs/<preset>.env]
# Every setting can also be overridden via environment variables.
set -euo pipefail

if [[ "${1:-}" != "" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$1"; set +a
fi

MODEL="${MODEL:-Qwen/Qwen3.8-27B}"
SERVED_NAME="${SERVED_NAME:-qwen3.8-27b}"
TP="${TP:-1}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-131072}"
GPU_MEM_UTIL="${GPU_MEM_UTIL:-0.92}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-64}"
PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"
TOOL_PARSER="${TOOL_PARSER:-qwen3_xml}"
KV_CACHE_DTYPE="${KV_CACHE_DTYPE:-auto}"
MM_LIMIT="${MM_LIMIT:-{\"image\":4,\"video\":1}}"
SPEC_DECODE="${SPEC_DECODE:-0}"
ENFORCE_EAGER="${ENFORCE_EAGER:-0}"
VLLM_API_KEY="${VLLM_API_KEY:-}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
export VLLM_LOGGING_LEVEL="${VLLM_LOGGING_LEVEL:-INFO}"

args=(
  serve "$MODEL"
  --served-model-name "$SERVED_NAME"
  --host "$HOST" --port "$PORT"
  --tensor-parallel-size "$TP"
  --max-model-len "$MAX_MODEL_LEN"
  --gpu-memory-utilization "$GPU_MEM_UTIL"
  --max-num-seqs "$MAX_NUM_SEQS"
  --reasoning-parser qwen3
  --enable-auto-tool-choice --tool-call-parser "$TOOL_PARSER"
  --limit-mm-per-prompt "$MM_LIMIT"
  --kv-cache-dtype "$KV_CACHE_DTYPE"
  --trust-remote-code
)
[[ -n "$VLLM_API_KEY" ]] && args+=(--api-key "$VLLM_API_KEY")
[[ "$SPEC_DECODE" == "1" ]] && args+=(--speculative-config '{"method":"mtp","num_speculative_tokens":3}')
[[ "$ENFORCE_EAGER" == "1" ]] && args+=(--enforce-eager)
# shellcheck disable=SC2206
[[ -n "$EXTRA_ARGS" ]] && args+=($EXTRA_ARGS)

echo "==> vllm ${args[*]}"
exec vllm "${args[@]}"
