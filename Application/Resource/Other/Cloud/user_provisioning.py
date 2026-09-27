#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Toho-Studio Virtual Linux: Local User Account Provisioner
Creates a distinct Linux user account with restricted permissions for each Toho-Studio user.
"""

import sys
import os
import subprocess
import json

USERS_FILE = "/opt/tohostudio-server/data/users_quota.json"

def create_linux_user(username: str, initial_prompts: int = 10000, plan_name: str = "3000円プラン"):
    print(f"Provisioning local Linux account for user [{username}]...")
    try:
        # Check if user already exists
        res = subprocess.run(["id", username], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode != 0:
            # Create user without shell login privilege for maximum sandboxing
            subprocess.run(["useradd", "-m", "-s", "/bin/rbash", username], check=True)
            print(f"Linux user '{username}' successfully created with sandboxed rbash environment.")
        else:
            print(f"Linux user '{username}' already exists. Updating quota records.")

        os.makedirs(os.path.dirname(USERS_FILE), exist_ok=True)
        users = {}
        if os.path.exists(USERS_FILE):
            try:
                with open(USERS_FILE, "r") as f:
                    users = json.load(f)
            except Exception:
                users = {}

        users[username] = {
            "remaining_prompts": initial_prompts,
            "monthly_plan": plan_name,
            "allocated_at": subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"]).decode().strip(),
            "status": "ACTIVE"
        }

        with open(USERS_FILE, "w") as f:
            json.dump(users, f, indent=2, ensure_ascii=False)
        print(f"User '{username}' registered with quota {initial_prompts} prompts in plan '{plan_name}'.")

    except Exception as e:
        print(f"Error provisioning user '{username}': {e}", file=sys.stderr)
        return False
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: user_provisioning.py <username> [initial_prompts] [plan_name]")
        sys.exit(1)
    user = sys.argv[1]
    prompts = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
    plan = sys.argv[3] if len(sys.argv) > 3 else "3000円プラン"
    create_linux_user(user, prompts, plan)
