import runpod
import subprocess
import requests
import time
import base64
import os

COMFY_DIR = "/workspace"
INPUT_DIR = os.path.join(COMFY_DIR, "input")
OUTPUT_DIR = os.path.join(COMFY_DIR, "output")

# 1. ComfyUI 실행 시 터미널 에러 로그를 파일로 기록
out_log = open("comfy.log", "w")
err_log = open("comfy_error.log", "w")

comfy_process = subprocess.Popen(
    ["python", "main.py", "--port", "8188", "--listen", "0.0.0.0"],
    cwd=COMFY_DIR,
    stdout=out_log,
    stderr=err_log
)

def handler(event):
    # 2. ComfyUI가 실행 중 죽었다면 원인을 PHP로 즉시 반환
    if comfy_process.poll() is not None:
        with open("comfy_error.log", "r") as f:
            error_details = f.read()
        return {"error": "ComfyUI Server Crashed on Startup", "details": error_details}

    # 3. 켜지는 데 오래 걸릴 수 있으므로 최대 120초 대기
    server_ready = False
    for _ in range(120):
        try:
            if requests.get("http://127.0.0.1:8188/").status_code == 200:
                server_ready = True
                break
        except:
            time.sleep(1)

    if not server_ready:
        with open("comfy_error.log", "r") as f:
            error_details = f.read()
        return {"error": "ComfyUI Startup Timeout", "details": error_details}

    # 4. 이미지 및 워크플로우 처리
    job_input = event.get("input", {})
    workflow = job_input.get("workflow")
    if not workflow:
        return {"error": "No workflow provided in the input"}

    os.makedirs(INPUT_DIR, exist_ok=True)
    input_images = job_input.get("images", [])
    for img_data in input_images:
        name = img_data.get("name")
        b64 = img_data.get("image")
        if name and b64:
            with open(os.path.join(INPUT_DIR, name), "wb") as f:
                f.write(base64.b64decode(b64))

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for f in os.listdir(OUTPUT_DIR):
        file_path = os.path.join(OUTPUT_DIR, f)
        if os.path.isfile(file_path):
            os.remove(file_path)

    try:
        submit_res = requests.post("http://127.0.0.1:8188/prompt", json={"prompt": workflow}).json()
        
        # 5. 모델이 없거나 노드가 없어서 발생한 ComfyUI 내부 에러 캡처
        if "error" in submit_res:
            return {"error": "ComfyUI rejected the workflow", "details": submit_res}
            
        prompt_id = submit_res.get("prompt_id")
        if not prompt_id:
            return {"error": "No prompt_id returned", "details": submit_res}

        while True:
            history_res = requests.get(f"http://127.0.0.1:8188/history/{prompt_id}").json()
            if prompt_id in history_res:
                break
            time.sleep(1.5)

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
