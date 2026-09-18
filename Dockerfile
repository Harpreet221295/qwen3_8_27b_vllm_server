# Optional custom image: official vLLM OpenAI server + this repo's serve script.
# Build: docker build -t <you>/qwen38-vllm . ; push; use as the RunPod pod image.
FROM vllm/vllm-openai:latest
WORKDIR /app
COPY serve.sh configs/ ./
RUN chmod +x /app/serve.sh
ENV PRESET=configs/h100_80gb_bf16.env
EXPOSE 8000
ENTRYPOINT ["/bin/bash", "-c", "/app/serve.sh /app/${PRESET}"]
