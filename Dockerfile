# 1. 가장 가볍고 안정적인 순정 파이썬 3.10 환경
FROM python:3.10-slim
USER root
ENV DEBIAN_FRONTEND=noninteractive

# 2. 필수 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    git wget libgl1-mesa-glx libglib2.0-0 build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 3. 최신 PyTorch (CUDA 12.1 호환) 직접 설치 (여기서 AttributeError 해결)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 4. ComfyUI 원본 가져오기
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# 5. 필수 패키지 설치 및 NumPy 다운그레이드 (여기서 NumPy 충돌 해결)
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir runpod requests rembg onnxruntime-gpu "numpy<2"

# 6. Rembg 커스텀 노드 다운로드 (배경 제거 플러그인)
RUN git clone https://github.com/Jcd1230/rembg-comfyui-node.git /workspace/custom_nodes/rembg-comfyui-node

# 7. 핸들러 복사 및 실행
COPY rp_handler.py /workspace/rp_handler.py
CMD ["python", "rp_handler.py"]
