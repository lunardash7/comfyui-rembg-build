FROM ubuntu:22.04
USER root
ENV DEBIAN_FRONTEND=noninteractive

# 1. 안정적인 우분투 공식 저장소를 통해 필수 패키지 및 파이썬 3.10 설치
RUN apt-get update && apt-get install -y \
    python3.10 python3-pip python3.10-venv \
    git wget libgl1-mesa-glx libglib2.0-0 build-essential \
    && rm -rf /var/lib/apt/lists/*

# 파이썬 명령어를 python3.10으로 연결
RUN ln -s /usr/bin/python3.10 /usr/bin/python

WORKDIR /workspace

# 2. 최신 PyTorch (CUDA 12.1 호환) 직접 설치 (여기서 이전의 AttributeError 해결)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 3. ComfyUI 원본 가져오기
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# 4. 필수 패키지 설치 및 NumPy 다운그레이드 (여기서 이전의 NumPy 충돌 해결)
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir runpod requests rembg onnxruntime-gpu "numpy<2"

# 5. Rembg 커스텀 노드 다운로드 (배경 제거 플러그인)
RUN git clone https://github.com/Jcd1230/rembg-comfyui-node.git /workspace/custom_nodes/rembg-comfyui-node

# 6. 핸들러 복사 및 실행
COPY rp_handler.py /workspace/rp_handler.py
CMD ["python", "rp_handler.py"]
