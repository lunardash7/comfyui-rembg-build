import runpod
import subprocess
import requests
import time
import base64
import os

COMFY_DIR = "/workspace"
INPUT_DIR = os.path.join(COMFY_DIR, "input")
OUTPUT_DIR = os.path.join(COMFY_DIR, "output")

# 1. 백그라운드에서 ComfyUI 실행
subprocess.Popen(
    ["python", "main.py", "--port", "8188", "--listen", "0.0.0.0"],
    cwd=COMFY_DIR
)

# 2. 서버가 완전히 켜질 때까지 대기
for _ in range(30):
    try:
        if requests.get("http://127.0.0.1:8188/").status_code == 200:
            break
    except:
        time.sleep(1)

def handler(event):
    job_input = event.get("input", {})
    
    # PHP에서 'workflow'라는 키로 보낸 데이터 받기
    workflow = job_input.get("workflow")
    if not workflow:
        return {"error": "No workflow provided in the input"}

    # 3. PHP에서 보낸 Base64 이미지 디코딩 및 input 폴더에 저장 (pose.png 등)
    os.makedirs(INPUT_DIR, exist_ok=True)
    input_images = job_input.get("images", [])
    for img_data in input_images:
        name = img_data.get("name")
        b64 = img_data.get("image")
        if name and b64:
            with open(os.path.join(INPUT_DIR, name), "wb") as f:
                f.write(base64.b64decode(b64))

    # 4. 이전 작업 결과물 삭제 (출력 폴더 초기화)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for f in os.listdir(OUTPUT_DIR):
        file_path = os.path.join(OUTPUT_DIR, f)
        if os.path.isfile(file_path):
            os.remove(file_path)

    try:
        # 5. ComfyUI로 워크플로우 전송
        submit_res = requests.post("http://127.0.0.1:8188/prompt", json={"prompt": workflow}).json()
        prompt_id = submit_res.get("prompt_id")
        
        if not prompt_id:
            return {"error": "ComfyUI prompt submission failed", "details": submit_res}

        # 6. 작업이 끝날 때까지 대기 (history 폴링)
        while True:
            history_res = requests.get(f"http://127.0.0.1:8188/history/{prompt_id}").json()
            if prompt_id in history_res:
                break
            time.sleep(1.5)

        # 7. 완성된 이미지를 찾아 Base64로 인코딩하여 반환
        output_b64_images = []
        for file_name in os.listdir(OUTPUT_DIR):
            if file_name.endswith(".png") or file_name.endswith(".jpg"):
                with open(os.path.join(OUTPUT_DIR, file_name), "rb") as f:
                    out_b64 = base64.b64encode(f.read()).decode("utf-8")
                    output_b64_images.append({
                        "name": file_name,
                        "image": out_b64
                    })

        return {"status": "success", "images": output_b64_images}
        
    except Exception as e:
        return {"error": str(e)}

runpod.serverless.start({"handler": handler})
