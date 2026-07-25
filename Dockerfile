FROM runpod/worker-comfyui:latest
USER root
RUN apt-get update && apt-get install -y libgl1-mesa-glx && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir rembg onnxruntime-gpu
