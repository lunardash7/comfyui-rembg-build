import runpod
import subprocess
import requests
import time

# 1. ComfyUI 서버를 백그라운드에서 실행
subprocess.Popen(
    ["python", "main.py", "--port", "8188", "--listen", "0.0.0.0"],
    cwd="/workspace"
)

# 2. 서버가 뜰 때까지 잠시 대기
time.sleep(10)

# 3. 런팟 서버리스 요청을 처리하는 핸들러
def handler(event):
    job_input = event.get("input", {})
    prompt = job_input.get("prompt", {})
    
    if not prompt:
        return {"error": "No prompt provided in the input"}

    try:
        # ComfyUI 내부 API로 작업 전달
        response = requests.post("http://127.0.0.1:8188/prompt", json={"prompt": prompt})
        return response.json()
    except Exception as e:
        return {"error": str(e)}

# 4. 서버리스 워커 시작
runpod.serverless.start({"handler": handler})
