# 1. 안정적인 공식 PyTorch 이미지를 베이스로 사용
FROM pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime
USER root
ENV DEBIAN_FRONTEND=noninteractive

# 2. 필수 시스템 패키지 설치 (rembg 구동용 libgl1-mesa-glx 포함)
RUN apt-get update && apt-get install -y \
    git wget libgl1-mesa-glx libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 3. ComfyUI 최신 버전 원본 가져오기
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# 4. ComfyUI 기본 요구사항 및 런팟/rembg 패키지 한 번에 설치
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir runpod requests rembg onnxruntime-gpu

# 5. 방금 만든 서버리스 핸들러 파일을 컨테이너 안으로 복사
COPY rp_handler.py /workspace/rp_handler.py

# 6. 컨테이너가 켜질 때 핸들러 실행
CMD ["python", "rp_handler.py"]
