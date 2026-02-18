#!/usr/bin/env python3
"""Redeploy a specific workflow by ID."""
import json, subprocess, sys

N8N_URL = "http://10.0.2.7:5678"

def get_api_key():
    return subprocess.check_output(
        "grep N8N_API_KEY /root/ideias_app/.env | cut -d= -f2-", shell=True
    ).decode().strip()

def curl(method, path, body=None):
    cmd = ["curl", "-s", "-X", method, f"{N8N_URL}{path}",
           "-H", f"X-N8N-API-KEY: {get_api_key()}",
           "-H", "Content-Type: application/json"]
    if body:
        cmd += ["-d", json.dumps(body)]
    return json.loads(subprocess.check_output(cmd).decode())

def deploy(workflow_id, filepath):
    with open(filepath) as f:
        wf = json.load(f)

    wf_body = {k: v for k, v in wf.items() if k != "active"}

    curl("POST", f"/api/v1/workflows/{workflow_id}/deactivate")
    r = curl("PUT", f"/api/v1/workflows/{workflow_id}", wf_body)
    err = r.get("message", "ok")[:80] if "message" in r else "ok"
    print(f"update: {err}")

    r2 = curl("POST", f"/api/v1/workflows/{workflow_id}/activate")
    print(f"activate: active={r2.get('active')} | {r2.get('message','')[:60]}")

if __name__ == "__main__":
    deploy(sys.argv[1], sys.argv[2])
