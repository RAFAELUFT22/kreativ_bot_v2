#!/usr/bin/env python3
"""Deploy corrected P0 workflows to N8N via API using Python urllib."""
import json, urllib.request, ssl, os, subprocess

N8N_API_KEY = subprocess.check_output(
    "grep N8N_API_KEY /root/ideias_app/.env | cut -d= -f2-", shell=True
).decode().strip()

# Get N8N internal IP  
N8N_IP = subprocess.check_output(
    "docker inspect kreativ_n8n --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'",
    shell=True
).decode().strip()
print(f"N8N IP: {N8N_IP}")
BASE_URL = f"http://{N8N_IP}:5678"

WORKFLOWS = {
    "tULwBOlfOnCuk586": "/root/ideias_app/n8n-workflows/18-save-progress-webhook.json",
    "oDg2TF7C0ne12fFg": "/root/ideias_app/n8n-workflows/02-get-student-module.json",
    "yKcjMnH87VsO5n9V": "/root/ideias_app/n8n-workflows/12-emit-certificate.json",
}

def api_call(method, path, body=None):
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        method=method,
        headers={
            "X-N8N-API-KEY": N8N_API_KEY,
            "Content-Type": "application/json",
        }
    )
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        return {"error": f"HTTP {e.code}: {body}"}
    except Exception as e:
        return {"error": str(e)[:200]}

for wf_id, filepath in WORKFLOWS.items():
    name = os.path.basename(filepath)
    print(f"\n{'='*50}")
    print(f"Deploying: {name} (ID: {wf_id})")
    
    with open(filepath) as f:
        wf = json.load(f)
    # Remove fields that conflict
    payload = {k: v for k, v in wf.items() if k not in ("active", "id")}
    
    # 1. Deactivate
    r = api_call("POST", f"/api/v1/workflows/{wf_id}/deactivate")
    print(f"  1. Deactivate: {r.get('active', r.get('error','?'))}")
    
    # 2. Update via PUT
    r = api_call("PUT", f"/api/v1/workflows/{wf_id}", payload)
    print(f"  2. Update: {str(r.get('name', r.get('error','?')))[:60]}")
    
    # 3. Activate
    r = api_call("POST", f"/api/v1/workflows/{wf_id}/activate")
    print(f"  3. Activate: {r.get('active', r.get('error','?'))}")

print(f"\n{'='*50}")
print("ALL DEPLOYMENTS COMPLETE")
