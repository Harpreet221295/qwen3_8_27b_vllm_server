# qwen_vllm_server — Qwen3.8-27B on RunPod with vLLM

Deploys `Qwen/Qwen3.8-27B` (dense 27B, **native image + video understanding**, 262K context,
thinking mode on by default) as an OpenAI-compatible server on a RunPod GPU pod.

## What the model can do
- Text chat, coding, long-horizon agentic tasks (tool calling)
- Image input (documents, charts, STEM diagrams, screenshots) and video input
- Thinking mode (`reasoning_effort`: low / medium / xhigh) or disabled per request
- 262,144-token native context, extendable to 1M with YaRN

## Pick a GPU (VRAM ladder)

| Variant | Weights | Fits on | Preset |
|---|---|---|---|
| `Qwen/Qwen3.8-27B` (BF16) | ~52 GB | 1× H100/A100 80GB, or 2× 48GB (TP=2) | `configs/h100_80gb_bf16.env` |
| `Qwen/Qwen3.8-27B-FP8` | ~26 GB | 1× L40S / A6000 / RTX 6000 Ada 48GB | `configs/l40s_48gb_fp8.env` |
| `unsloth/Qwen3.8-27B-NVFP4` | ~12 GB | RTX 5090 / B200 (Blackwell only) | `configs/rtx5090_nvfp4.env` |

Recommended for a first run: **1× H100 80GB, BF16** (reference precision, plenty of KV cache).

## Deploy on RunPod (GPU Pod, not Serverless)

1. RunPod → Pods → Deploy. Choose the GPU. Template: **vLLM** (`vllm/vllm-openai:latest`)
   or a PyTorch template (then use `scripts/install_vllm.sh`).
2. Container disk ≥ 100 GB. Attach a Network Volume (≥ 100 GB) at `/root/.cache/huggingface`
   so weights persist across restarts.
3. Expose **HTTP port 8000**. Set env vars `HF_TOKEN` (optional for public model) and `VLLM_API_KEY`.
4. Container start command (or run manually in the pod terminal):
   ```bash
   git clone <this repo> /workspace/qwen_vllm_server && cd /workspace/qwen_vllm_server
   ./serve.sh configs/h100_80gb_bf16.env
   ```
5. Wait for `Application startup complete`. Endpoint:
   `https://<POD_ID>-8000.proxy.runpod.net/v1`

Alternatively create the pod from your Mac with `python runpod/create_pod.py` (needs `RUNPOD_API_KEY`).

## Verify
```bash
export QWEN_BASE_URL=https://<POD_ID>-8000.proxy.runpod.net/v1
export QWEN_API_KEY=<VLLM_API_KEY>
./scripts/healthcheck.sh
python scripts/smoke_test.py      # text + image + tool call
```

## Serve flags that matter
- `--reasoning-parser qwen3` — splits thinking into `reasoning_content` (required)
- `--enable-auto-tool-choice --tool-call-parser qwen3_xml` — OpenAI-style tool calls
  (`qwen3_coder` also works; set `TOOL_PARSER` in the config)
- `--limit-mm-per-prompt '{"image":4,"video":1}'` — images/videos per request
- `--max-model-len` — 131072 default here; raise to 262144 if KV cache allows
- `--kv-cache-dtype fp8` — ~2× KV capacity; set `KV_CACHE_DTYPE=fp8`
- `--speculative-config '{"method":"mtp","num_speculative_tokens":3}'` — built-in MTP
  draft head, set `SPEC_DECODE=1` (acceptance ~0.77–0.90 reported)

## Request-side controls
- Disable thinking: `extra_body={"chat_template_kwargs": {"enable_thinking": False}}`
- Thinking effort: `extra_body={"chat_template_kwargs": {"reasoning_effort": "low"}}`
- Sampling (thinking): temp 1.0, top_p 0.95, top_k 20
- Sampling (non-thinking): temp 0.7, top_p 0.8, top_k 20, presence_penalty 1.5

## Requirements
vLLM ≥ 0.17.0, transformers ≥ 5.8.0 (the `vllm/vllm-openai:latest` image satisfies this).

## Sources
- https://huggingface.co/Qwen/Qwen3.8-27B
- https://recipes.vllm.ai/Qwen/Qwen3.8-27B
- https://www.orcarouter.ai/blog/qwen-3-8-27b-vllm
- https://www.runpod.io/articles/guides/deploy-vllm-runpod-docker
