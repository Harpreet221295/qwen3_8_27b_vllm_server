# RunPod pod settings (manual UI path)

| Field | Value |
|---|---|
| Pod type | GPU Pod (on-demand or spot) |
| GPU | H100 80GB (BF16) · L40S 48GB (FP8) · RTX 5090 (NVFP4) |
| Image | `vllm/vllm-openai:latest` |
| Container disk | 120 GB |
| Volume | 120 GB at `/root/.cache/huggingface` |
| Expose HTTP ports | `8000` |
| Env | `VLLM_API_KEY=<secret>`, `HF_TOKEN=<optional>`, `HF_HUB_ENABLE_HF_TRANSFER=1` |
| Container start command | `bash -lc "git clone <repo> /workspace/server; cd /workspace/server; ./serve.sh configs/h100_80gb_bf16.env"` |

Endpoint after startup: `https://<POD_ID>-8000.proxy.runpod.net/v1`

Tips
- First boot downloads weights (~52 GB BF16). Subsequent boots load from the volume.
- If you see OOM at startup, lower `MAX_MODEL_LEN` or `GPU_MEM_UTIL` in the preset.
- `nvidia-smi` in the pod web terminal to confirm the GPU; `tail -f` the container logs for `Application startup complete`.
- Stop the pod when idle; you pay per second while it runs.
