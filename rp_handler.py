import runpod
import subprocess
import requests
import time
import base64
import os
import shutil

COMFY_DIR = "/workspace"
INPUT_DIR = os.path.join(COMFY_DIR, "input")
OUTPUT_DIR = os.path.join(COMFY_DIR, "output")

# 네트워크 볼륨 마운트 로직 (정상 작동 확인됨)
RUNPOD_VOL = "/runpod-volume"
if os.path.exists(RUNPOD_VOL):
    vol_models = os.path.join(RUNPOD_VOL, "models")
    comfy_models = os.path.join(COMFY_DIR, "models")
    
    if os.path.exists(vol_models):
        if os.path.exists(comfy_models) and not os.path.islink(comfy_models):
            shutil.rmtree(comfy_models)
        if not os.path.exists(comfy_models):
            os.symlink(vol_models, comfy_models)

# 로그 통합 및 실시간 출력 설정 (-u 옵션 및 stderr 통합)
out_err_log = open("comfy_server.log", "w")
comfy_process = subprocess.Popen(
    ["python", "-u", "main.py", "--port", "8188", "--listen", "0.0.0.0"],
    cwd=COMFY_DIR,
    stdout=out_err_log,
    stderr=subprocess.STDOUT
)

def handler(event):
    if comfy_process.poll() is not None:
        with open("comfy_server.log", "r") as f:
            return {"error": "ComfyUI Server Crashed", "details": f.read()}

    server_ready = False
    for _ in range(120):
        try:
            if requests.get("http://127.0.0.1:8188/").status_code == 200:
                server_ready = True
                break
        except:
            time.sleep(1)

    if not server_ready:
        with open("comfy_server.log", "r") as f:
            return {"error": "ComfyUI Startup Timeout", "details": f.read()}

    job_input = event.get("input", {})
    workflow = job_input.get("workflow")
    if not workflow:
        return {"error": "No workflow provided in the input"}

    os.makedirs(INPUT_DIR, exist_ok=True)
    for img_data in job_input.get("images", []):
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
        
        # 에러 발생 시 완벽한 로그 추출
        if "error" in submit_res:
            with open("comfy_server.log", "r") as f:
                server_log = f.read()[-4000:]
                
            installed_nodes = os.listdir(os.path.join(COMFY_DIR, "custom_nodes"))
            
            return {
                "error": "ComfyUI rejected the workflow", 
                "details": submit_res,
                "installed_nodes_check": installed_nodes,
                "server_log": server_log
            }
            
        prompt_id = submit_res.get("prompt_id")
        while True:
            history_res = requests.get(f"http://127.0.0.1:8188/history/{prompt_id}").json()
            if prompt_id in history_res:
                break
            time.sleep(1.5)

        output_b64_images = []
        for file_name in os.listdir(OUTPUT_DIR):
            if file_name.endswith(".png") or file_name.endswith(".jpg"):
                with open(os.path.join(OUTPUT_DIR, file_name), "rb") as f:
                    output_b64_images.append({
                        "name": file_name,
                        "image": base64.b64encode(f.read()).decode("utf-8")
                    })

        return {"status": "success", "images": output_b64_images}
        
    except Exception as e:
        return {"error": str(e)}

runpod.serverless.start({"handler": handler})
