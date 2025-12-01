import json
import os
import requests
from typing import Optional

FORMULA_API = "https://formulae.brew.sh/api/formula/{pkg}.json"
CASK_API = "https://formulae.brew.sh/api/cask/{pkg}.json"


def latest_brew_version(pkg_name: str) -> Optional[str]:
    """
    Return latest version string for a Homebrew formula or cask, or None if not found.

    Tries:
      1. formula API: /api/formula/{pkg}.json  -> versions.stable
      2. cask API:    /api/cask/{pkg}.json     -> version
    """
    # 1) Try as formula
    try:
        r = requests.get(FORMULA_API.format(pkg=pkg_name), timeout=15)
        if r.status_code == 200:
            data = r.json()
            versions = data.get("versions", {})
            stable = versions.get("stable")
            if isinstance(stable, str) and stable:
                return stable
    except Exception:
        pass

    # 2) Try as cask
    try:
        r = requests.get(CASK_API.format(pkg=pkg_name), timeout=15)
        if r.status_code == 200:
            data = r.json()
            # cask API exposes a single "version" string (can include comma)
            version = data.get("version")
            if isinstance(version, str) and version:
                return version
    except Exception:
        pass

    return None


def update_macos_tools() -> None:
    """
    Update macOS tools.json (mac/bin/tools.json) with latest versions from Homebrew.
    """
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
    tools_path = os.path.join(repo_root, "macos", "bin", "tools.json")

    if not os.path.exists(tools_path):
        raise FileNotFoundError(f"macOS tools.json not found at: {tools_path}")

    with open(tools_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    roles = data.get("roles", {})

    for role_name, role_info in roles.items():
        tools = role_info.get("tools", {})
        for tool_id in list(tools.keys()):
            ver = latest_brew_version(tool_id)
            if ver:
                tools[tool_id] = ver
                print(f"[macOS:{role_name}] {tool_id} -> {ver}")
            else:
                print(f"[macOS:{role_name}] {tool_id} -> (version not found)")

    with open(tools_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"macOS tools updated successfully in {tools_path}")


if __name__ == "__main__":
    update_macos_tools()
