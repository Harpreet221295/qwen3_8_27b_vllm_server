"""Smoke test: text, thinking, image, tool call. pip install openai pillow
QWEN_BASE_URL=https://<pod>-8000.proxy.runpod.net/v1 QWEN_API_KEY=... python scripts/smoke_test.py
"""
import base64, io, json, os, time
from openai import OpenAI
from PIL import Image, ImageDraw

BASE = os.environ.get("QWEN_BASE_URL", "http://localhost:8000/v1")
KEY = os.environ.get("QWEN_API_KEY", "none")
MODEL = os.environ.get("QWEN_MODEL", "qwen3.8-27b")
client = OpenAI(base_url=BASE, api_key=KEY)

def step(name):
    print(f"\n=== {name} ===")

step("1. plain chat (thinking off)")
t = time.time()
r = client.chat.completions.create(
    model=MODEL, messages=[{"role": "user", "content": "In one sentence, what is vLLM?"}],
    max_tokens=100, temperature=0.7, top_p=0.8,
    extra_body={"chat_template_kwargs": {"enable_thinking": False}, "top_k": 20})
print(r.choices[0].message.content, f"({time.time()-t:.1f}s)")

step("2. thinking mode (reasoning_content separate)")
r = client.chat.completions.create(
    model=MODEL, messages=[{"role": "user", "content": "What is 17*23? Answer with the number only."}],
    max_tokens=2048, temperature=1.0, top_p=0.95,
    extra_body={"chat_template_kwargs": {"reasoning_effort": "low"}, "top_k": 20})
m = r.choices[0].message
print("reasoning chars:", len(getattr(m, "reasoning_content", None) or getattr(m, "reasoning", None) or ""), "| answer:", m.content)

step("3. image input (synthetic)")
img = Image.new("RGB", (400, 200), "white"); d = ImageDraw.Draw(img)
d.rectangle([20, 20, 180, 180], fill="red"); d.ellipse([220, 20, 380, 180], fill="blue")
d.text((150, 185), "shapes", fill="black")
buf = io.BytesIO(); img.save(buf, format="PNG")
data_url = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
r = client.chat.completions.create(
    model=MODEL, max_tokens=200,
    messages=[{"role": "user", "content": [
        {"type": "image_url", "image_url": {"url": data_url}},
        {"type": "text", "text": "What shapes and colors are in this image?"}]}],
    extra_body={"chat_template_kwargs": {"enable_thinking": False}})
print(r.choices[0].message.content)

step("4. tool calling")
tools = [{"type": "function", "function": {
    "name": "get_weather", "description": "Get weather for a city",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]
r = client.chat.completions.create(
    model=MODEL, tools=tools, tool_choice="auto", max_tokens=300,
    messages=[{"role": "user", "content": "What's the weather in Toronto right now?"}],
    extra_body={"chat_template_kwargs": {"enable_thinking": False}})
tc = r.choices[0].message.tool_calls
print("tool_calls:", json.dumps([t.function.model_dump() for t in tc], indent=1) if tc else "NONE (check --tool-call-parser)")

print("\nAll smoke steps ran.")
