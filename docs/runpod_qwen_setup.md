# RunPod + vLLM setup for Qwen3.8-27B (as actually done, 2026-09-19)

## 1. The model
- `Qwen/Qwen3.8-27B`: dense 27B, native vision-language (image + video input), 262K context, thinking on by default.
- BF16 weights ≈ 52 GB → needs one 80 GB GPU. FP8 checkpoint (`Qwen/Qwen3.8-27B-FP8`, ~26 GB) fits a 48 GB card.
- Needs vLLM ≥ 0.17 and transformers ≥ 5.8. The `vllm/vllm-openai:latest` image satisfies both.

## 2. GPU choice
| GPU | VRAM | BF16 fits | RunPod community price (Sep 2026) | Notes |
|---|---|---|---|---|
| A100 SXM 80GB | 80 | yes | $1.59/hr (same as PCIe on our day) | **what we use**; SXM has more bandwidth than PCIe |
| H100 80GB | 80 | yes | $1.99–2.69/hr | ~1.7× faster decode (3.35 TB/s vs 2.0 TB/s), native FP8 |
| L40S 48GB | 48 | no (FP8 only) | $0.79/hr | fine for chat/vision tests, weaker for agent runs |
| A40 48GB | 48 | no | $0.35/hr | Ampere, no FP8 compute: skip |

Decode is memory-bound: tokens/s ≈ bandwidth ÷ weight bytes. On the A100 we measure ~30 tok/s single-stream (ceiling ≈ 38).

## 3. Pod creation (RunPod web UI)
1. Pods → Deploy → **A100 SXM**, Community Cloud, On-Demand.
2. Pod name `qwen38-27B`.
3. Template: **vLLM Latest** (verified; image `vllm/vllm-openai:latest`). Not the PyTorch template.
4. Click **Edit** on the template and set:
   - **Container start command** (this image appends it to `vllm serve`):
     ```
     Qwen/Qwen3.8-27B --served-model-name qwen3.8-27b --host 0.0.0.0 --port 8000 --max-model-len 131072 --gpu-memory-utilization 0.92 --max-num-seqs 64 --reasoning-parser qwen3 --enable-auto-tool-choice --tool-call-parser qwen3_xml --trust-remote-code
     ```
   - **Container disk** 120 GB, **Volume disk** 120 GB mounted at `/workspace`.
   - **Expose HTTP ports** `8000`. TCP `22` stays for SSH.
   - **Environment variables**: `VLLM_API_KEY=<48-char random string from openssl rand -hex 24>`,
     `HF_HOME=/workspace/.huggingface` (so the 52 GB download lands on the persistent volume).
5. Set overrides → Deploy On-Demand. Top up balance first (≥ $15); RunPod kills pods at $0.

First boot: ~2 min image pull, ~5 min weight download, ~3 min compile/warm-up → `Application startup complete`.
Later boots: weights come from the volume, ~90 s.

## 4. What the flags mean
| flag | why |
|---|---|
| `--served-model-name qwen3.8-27b` | the model id clients send; avoids `/` in names |
| `--max-model-len 131072` | per-request context cap; KV cache actually holds ~304K tokens so 262144 also fits |
| `--gpu-memory-utilization 0.92` | 52 GB weights + rest for KV cache |
| `--reasoning-parser qwen3` | thinking comes back in a separate `reasoning` field |
| `--enable-auto-tool-choice --tool-call-parser qwen3_xml` | structured OpenAI-style tool calls (agent harness depends on this) |
| `--trust-remote-code` | required for the Qwen3.5-family architecture |

Not used (yet): `--limit-mm-per-prompt {"image":4,"video":1}` (needs JSON; RunPod's start-command box splits on spaces and we
could not confirm quotes survive, so default = 1 image per request), `--kv-cache-dtype fp8`, `--speculative-config {"method":"mtp",...}`
(built-in MTP draft head, ~1.5–2× decode speedup, same quoting question).

## 5. Endpoint & access
- OpenAI-compatible: `https://<POD_ID>-8000.proxy.runpod.net/v1` (ours: pod `f2yfyf7oaffpx6`).
  Also serves Anthropic's `/v1/messages` natively.
- Auth: `Authorization: Bearer $VLLM_API_KEY`. The key lives in `~/.zshrc` as `QWEN_API_KEY` and in the gitignored `.env`
  of the workloads and harness repos. Never in chat or git.
- Health: `GET /health` → 200. Metrics: `GET /metrics` (Prometheus; `vllm:cache_config_info` shows KV capacity).
- SSH from the Mac (key already registered in RunPod): `ssh <POD_ID>-<hash>@ssh.runpod.io -i ~/.ssh/id_ed25519`.
  The proxy only gives an interactive shell, so pipe commands on stdin with `-tt`:
  `printf 'nvidia-smi\nexit\n' | ssh -tt <pod>@ssh.runpod.io -i ~/.ssh/id_ed25519`
- Container logs: RunPod UI → pod → Logs → Container. Inside the container `/proc/1/cmdline` shows how the args were split.

## 6. Verify
```bash
export QWEN_BASE_URL=https://<POD_ID>-8000.proxy.runpod.net/v1 ; export QWEN_API_KEY=...
./scripts/healthcheck.sh                      # /health, /models, one chat completion
python scripts/smoke_test.py                  # text, thinking, image, tool call
```

## 7. Request-side controls
- Thinking off: `extra_body={"chat_template_kwargs": {"enable_thinking": false}}`; sample temp 0.7, top_p 0.8, top_k 20, presence_penalty 1.5.
- Thinking on: `chat_template_kwargs: {"reasoning_effort": "low"|"medium"|"xhigh"}` (default xhigh); temp 1.0, top_p 0.95, top_k 20.
  Only these three levels exist; "high" is rejected.
- Reasoning arrives as `message.reasoning` (non-stream) / `delta.reasoning` (stream) in this vLLM build.
- Structured output: `response_format` (json_object / json_schema) or `extra_body={"structured_outputs": {"choice": [...]}}` /
  `{"regex": ...}`. The old `guided_choice` / `guided_regex` names are ignored.
- Images: OpenAI `image_url` content parts, base64 data URLs work.

## 8. Gotchas we hit
1. `--limit-mm-per-prompt image=4,video=1` → "cannot be converted"; current vLLM wants JSON. Pod restarted every 16 s until the
   flag was removed via ⋮ → Edit Pod.
2. Template default `VLLM_API_KEY=sk-$RUNPOD_POD_ID` is guessable from the public URL: replace with a random secret.
3. `litellm` logs "model isn't mapped" for cost lookup on every call: harmless; silenced with `litellm.register_model`.
4. Editing a running pod resets the container (not the volume). Weights survive; anything in `/root` does not.

## 9. Cost & lifecycle
- Running: $1.59/hr GPU + ~$0.03/hr disks. Stopped: only the disk charge (~$0.03/hr) and the volume keeps the weights.
- Stop when idle (pod page → Stop). Resume starts vLLM again automatically (start command re-runs).
- Terminate deletes the volume too → next start re-downloads 52 GB.
- Optional scripts (need `RUNPOD_API_KEY`, which we chose not to use yet): `runpod/create_pod.py`, `runpod/manage_pod.py`.

## 10. Upgrades to consider
- `--max-model-len 262144` (fits; concurrency at full length ≈ 1).
- MTP speculative decoding for ~1.5–2× single-stream speed.
- Move to `serve.sh` from this repo (needs the repo public or a deploy key) to get presets and easy flag changes.
- H100 if agent runs with thinking xhigh feel slow.
