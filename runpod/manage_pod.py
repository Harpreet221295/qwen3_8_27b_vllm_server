"""Manage the RunPod pod from your laptop. export RUNPOD_API_KEY=...
  python runpod/manage_pod.py list
  python runpod/manage_pod.py status <pod_id>
  python runpod/manage_pod.py stop <pod_id>        # stops billing for GPU; volume + disk kept, can resume
  python runpod/manage_pod.py resume <pod_id>
  python runpod/manage_pod.py terminate <pod_id>   # deletes the pod (asks for confirmation)
"""
import os, sys
import runpod

runpod.api_key = os.environ["RUNPOD_API_KEY"]
cmd, *rest = sys.argv[1:] or ["list"]

if cmd == "list":
    for p in runpod.get_pods():
        print(f"{p['id']}  {p['name']:<24} {p.get('desiredStatus','?'):<8} {p['machine'].get('gpuDisplayName','?')}  "
              f"${p.get('costPerHr','?')}/hr")
elif cmd == "status":
    p = runpod.get_pod(rest[0]); print(p.get("desiredStatus"), "|", f"https://{rest[0]}-8000.proxy.runpod.net/v1")
elif cmd == "stop":
    runpod.stop_pod(rest[0]); print("stopped", rest[0], "(GPU billing off, storage billing continues)")
elif cmd == "resume":
    runpod.resume_pod(rest[0], gpu_count=1); print("resuming", rest[0])
elif cmd == "terminate":
    if input(f"terminate pod {rest[0]}? This deletes it. [y/N] ").lower() == "y":
        runpod.terminate_pod(rest[0]); print("terminated", rest[0])
else:
    sys.exit(__doc__)
