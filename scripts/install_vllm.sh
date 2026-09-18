#!/usr/bin/env bash
# Use this inside a plain RunPod PyTorch pod (no vLLM preinstalled).
set -euo pipefail
pip install -U pip
pip install -U "vllm>=0.17.0" "transformers>=5.8.0" hf_transfer
python -c "import vllm, transformers; print('vllm', vllm.__version__, '| transformers', transformers.__version__)"
nvidia-smi
