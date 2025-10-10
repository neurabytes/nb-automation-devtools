import json
import requests
import os
import xml.etree.ElementTree as ET

CHOCOLATEY_API = "https://community.chocolatey.org/api/v2/Packages()?$filter=Id eq '{pkg}'&$orderby=Published desc"

def latest_version(pkg_name: str) -> str | None:
    """Return latest version string for a Chocolatey package id, or None if not found."""
    try:
        r = requests.get(CHOCOLATEY_API.format(pkg=pkg_name), timeout=15)
        if r.status_code != 200:
            return None
        root = ET.fromstring(r.content)
        ns = {"d": "http://schemas.microsoft.com/ado/2007/08/dataservices"}
        ver = root.find(".//d:Version", ns)
        return ver.text if ver is not None else None
    except Exception:
        return None

def update_tools():
    # tools.json path (repoRoot/windows/bin/tools.json)
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
    tools_path = os.path.join(repo_root, "windows", "bin", "tools.json")

    with open(tools_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Expect the new structure with roles
    roles = data.get("roles", {})

    # Iterate every role and every tool under it
    for role_name, role_info in roles.items():
        tools = role_info.get("tools", {})
        for tool_id in list(tools.keys()):
            ver = latest_version(tool_id)
            if ver:
                tools[tool_id] = ver
                print(f"[{role_name}] {tool_id} -> {ver}")
            else:
                print(f"[{role_name}] {tool_id} -> (version not found)")

    # Save the updated file (preserves ignore_checksum_tools and anything else)
    with open(tools_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"Tools updated successfully in {tools_path}")

if __name__ == "__main__":
    update_tools()
