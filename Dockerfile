FROM ubuntu:22.04
USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3.10 python3-pip python3.10-venv \
    git wget libgl1-mesa-glx libglib2.0-0 build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3.10 /usr/bin/python

WORKDIR /workspace

RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

RUN pip install --no-cache-dir -r requirements.txt
# OpenCV 충돌 방지를 위해 headless 패키지 추가
RUN pip install --no-cache-dir runpod requests rembg onnxruntime-gpu "numpy<2" opencv-python-headless

# Rembg 커스텀 노드 다운로드 및 해당 노드의 요구사항 강제 설치
RUN git clone https://github.com/Jcd1230/rembg-comfyui-node.git /workspace/custom_nodes/rembg-comfyui-node
RUN cd /workspace/custom_nodes/rembg-comfyui-node && pip install --no-cache-dir -r requirements.txt || true

# CLIPSeg 클론 후 requirements.txt에서 torch와 numpy 관련 항목을 제거하고 종속성 설치
RUN cd /workspace/custom_nodes && \
    git clone https://github.com/time-river/ComfyUI-CLIPSeg.git && \
    cd ComfyUI-CLIPSeg && \
    sed -i '/torch/d' requirements.txt && \
    sed -i '/numpy/d' requirements.txt && \
    pip install -r requirements.txt

COPY rp_handler.py /workspace/rp_handler.py
CMD ["python", "rp_handler.py"]
