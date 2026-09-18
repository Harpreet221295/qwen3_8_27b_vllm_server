"""Create a RunPod GPU pod running vLLM for Qwen3.8-27B from your laptop.
pip install runpod ; export RUNPOD_API_KEY=... ; python runpod/create_pod.py --gpu "NVIDIA H100 80GB HBM3"
"""
import argparse, os, time
import runpod

p = argparse.ArgumentParser()
p.add_argument("--name", default="qwen38-27b-vllm")
p.add_argument("--gpu", default="NVIDIA H100 80GB HBM3")
p.add_argument("--gpu-count", type=int, default=1)
p.add_argument("--preset", default="h100_80gb_bf16.env")
p.add_argument("--repo", required=True, help="git URL of this qwen_vllm_server repo")
p.add_argument("--api-key", default=os.environ.get("VLLM_API_KEY", "change-me"))
p.add_argument("--disk", type=int, default=120)
p.add_argument("--volume", type=int, default=120)
a = p.parse_args()

runpod.api_key = os.environ["RUNPOD_API_KEY"]
start_cmd = (
    "bash -lc 'apt-get update -qq && apt-get install -y -qq git >/dev/null; "
    f"git clone {a.repo} /workspace/server || true; cd /workspace/server; "
    f"./serve.sh configs/{a.preset}'"
)
pod = runpod.create_pod(
    name=a.name, image_name="vllm/vllm-openai:latest", gpu_type_id=a.gpu, gpu_count=a.gpu_count,
    container_disk_in_gb=a.disk, volume_in_gb=a.volume, volume_mount_path="/root/.cache/huggingface",
    ports="8000/http", docker_args=start_cmd,
    env={"VLLM_API_KEY": a.api_key, "HF_TOKEN": os.environ.get("HF_TOKEN", ""),
         "HF_HUB_ENABLE_HF_TRANSFER": "1"},
)
pid = pod["id"]
print("pod id:", pid)
print("endpoint (once vLLM is up):", f"https://{pid}-8000.proxy.runpod.net/v1")
print("watch logs in the RunPod console; first boot downloads ~52 GB of weights.")
