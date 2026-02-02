#!/usr/bin/env python3
"""
auto_config.py - Automatically update Flutter api_config.dart with local IP
Usage: python auto_config.py
"""

import socket
import re
from pathlib import Path

def get_local_ip():
    """Get the local IPv4 address"""
    try:
        # Connect to a non-routable address to determine local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return None

def update_api_config(ip):
    """Update api_config.dart with the new IP"""
    # The script is in the project root, so we go into lib/config
    config_path = Path(__file__).parent / "lib/config/api_config.dart"
    
    if not config_path.exists():
        print(f"❌ File not found: {config_path}")
        return False
    
    with open(config_path, 'r') as f:
        lines = f.readlines()

    new_url = f"http://{ip}:3000/api"
    new_lines = []
    updated = False

    for line in lines:
        if "static const String baseUrl" in line and not line.strip().startswith("//"):
            # Preserve indentation
            indentation = line[:line.find("static")]
            new_lines.append(f"{indentation}static const String baseUrl = '{new_url}';\n")
            updated = True
        else:
            new_lines.append(line)

    if updated:
        with open(config_path, 'w') as f:
            f.writelines(new_lines)
        print(f"✅ Updated api_config.dart")
        print(f"   BaseURL: {new_url}")
        return True
    else:
        print("🤷 No active baseUrl found to update.")
        return False

if __name__ == "__main__":
    ip = get_local_ip()
    if ip:
        print(f"🔍 Local IPv4: {ip}")
        update_api_config(ip)
    else:
        print("❌ Could not detect local IP address")
