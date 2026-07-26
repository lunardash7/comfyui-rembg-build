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

RUN mkdir -p /workspace/custom_nodes

RUN <<'EOF' > /workspace/custom_nodes/standalone_clipseg.py
import torch
import numpy as np
from transformers import CLIPSegProcessor, CLIPSegForImageSegmentation
from PIL import Image

class StandaloneCLIPSeg:
    @classmethod
    def INPUT_TYPES(s):
        return {"required": {"image": ("IMAGE",), "prompt": ("STRING", {"multiline": False, "default": "clothes"})}}
    
    RETURN_TYPES = ("MASK",)
    FUNCTION = "segment"
    CATEGORY = "mask"
    
    def __init__(self):
        self.processor = None
        self.model = None

    def segment(self, image, prompt):
        if self.processor is None:
            self.processor = CLIPSegProcessor.from_pretrained("CIDAS/clipseg-rd64-refined")
            self.model = CLIPSegForImageSegmentation.from_pretrained("CIDAS/clipseg-rd64-refined")
        
        i = 255. * image[0].cpu().numpy()
        img = Image.fromarray(np.clip(i, 0, 255).astype(np.uint8))
        
        inputs = self.processor(text=[prompt], images=[img], padding="max_length", return_tensors="pt")
        with torch.no_grad():
            outputs = self.model(**inputs)
        
        mask = torch.sigmoid(outputs.logits).unsqueeze(0).unsqueeze(0)
        mask = torch.nn.functional.interpolate(mask, size=(img.height, img.width), mode='bilinear').squeeze()
        
        return (mask.unsqueeze(0),)

NODE_CLASS_MAPPINGS = {"CLIPSeg": StandaloneCLIPSeg}
EOF

COPY rp_handler.py /workspace/rp_handler.py
CMD ["python", "rp_handler.py"]
