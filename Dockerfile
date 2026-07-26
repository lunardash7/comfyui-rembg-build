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

RUN python3 -c 'import os; code = "import torch\nimport numpy as np\nfrom transformers import CLIPSegProcessor, CLIPSegForImageSegmentation\nfrom PIL import Image\n\nclass StandaloneCLIPSeg:\n    @classmethod\n    def INPUT_TYPES(s):\n        return {\n            \"required\": {\"image\": (\"IMAGE\",)},\n            \"optional\": {\n                \"text\": (\"STRING\", {\"multiline\": False, \"default\": \"\"}),\n                \"prompt\": (\"STRING\", {\"multiline\": False, \"default\": \"\"}),\n                \"blur\": (\"FLOAT\", {\"default\": 3.0}),\n                \"threshold\": (\"FLOAT\", {\"default\": 0.4}),\n                \"dilation_factor\": (\"INT\", {\"default\": 4}),\n                \"dilation\": (\"INT\", {\"default\": 4})\n            }\n        }\n    \n    RETURN_TYPES = (\"MASK\", \"IMAGE\", \"MASK\")\n    RETURN_NAMES = (\"Mask\", \"Heatmap Mask\", \"BW Mask\")\n    FUNCTION = \"segment\"\n    CATEGORY = \"mask\"\n    \n    def __init__(self):\n        self.processor = None\n        self.model = None\n\n    def segment(self, image, text=\"\", prompt=\"\", **kwargs):\n        actual_prompt = text if text else prompt\n        if not actual_prompt:\n            actual_prompt = \"clothes\"\n        \n        if self.processor is None:\n            self.processor = CLIPSegProcessor.from_pretrained(\"CIDAS/clipseg-rd64-refined\")\n            self.model = CLIPSegForImageSegmentation.from_pretrained(\"CIDAS/clipseg-rd64-refined\")\n        \n        i = 255. * image[0].cpu().numpy()\n        img = Image.fromarray(np.clip(i, 0, 255).astype(np.uint8))\n        \n        inputs = self.processor(text=[actual_prompt], images=[img], padding=\"max_length\", return_tensors=\"pt\")\n        with torch.no_grad():\n            outputs = self.model(**inputs)\n        \n        mask = torch.sigmoid(outputs.logits).unsqueeze(0).unsqueeze(0)\n        mask = torch.nn.functional.interpolate(mask, size=(img.height, img.width), mode=\"bilinear\").squeeze()\n        mask_tensor = mask.unsqueeze(0)\n        return (mask_tensor, image, mask_tensor)\n\nNODE_CLASS_MAPPINGS = {\"CLIPSeg\": StandaloneCLIPSeg}\n"; open("/workspace/custom_nodes/standalone_clipseg.py", "w").write(code)'

COPY rp_handler.py /workspace/rp_handler.py

# --- CLIPSeg 차원(Dimension) 버그 수정 자동 패치 ---
RUN python3 -c "import os;\
path = '/workspace/custom_nodes/standalone_clipseg.py';\
if os.path.exists(path):\
    with open(path, 'r') as f: data = f.read();\
    old = 'mask = torch.nn.functional.interpolate(mask, size=(img.height, img.width), mode=\"bilinear\").squeeze()';\
    new = 'mask = mask.unsqueeze(1)\\n        mask = torch.nn.functional.interpolate(mask, size=(img.height, img.width), mode=\"bilinear\")\\n        mask = mask.squeeze(1)';\
    data = data.replace(old, new);\
    with open(path, 'w') as f: f.write(data);\
    print('CLIPSeg patch applied successfully.')\
"

CMD ["python", "rp_handler.py"]
