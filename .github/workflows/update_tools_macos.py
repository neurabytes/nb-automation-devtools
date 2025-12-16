import json
import os
import shutil
import subprocess
from typing import Optional, Any, Dict


def _brew_exists() -> bool:
    return shutil.which("brew") is not None


def _brew_info_json_v2(pkg: str, kind: str) -> Optional[Dict[str, Any]]:
    """
    kind: 'formula' or 'cask'
    Returns Homebrew JSON v2 dict or None.
    """
    if not _brew_exists():
        return None

    cmd = ["brew", "info", "--json=v2", f"--{kind}", pkg]
    p = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if p.returncode != 0 or not p.stdout.strip():
        return None

    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return None


def _extract_formula_version(j: Dict[str, Any]) -> Optional[str]:
    try:
        formulae = j.get("formulae") or []
        if not formulae:
            return None
        stable = (formulae[0].get("versions") or {}).get("stable")
        return stable if isinstance(stable, str) and stable else None
    except Exception:
        return None


def _extract_cask_version(j: Dict[str, Any]) -> Optional[str]:
    try:
        casks = j.get("casks") or []
        if not casks:
            return None
        version = casks[0].get("version")
        return version if isinstance(version, str) and version else None
    except Exception:
        return None


def latest_brew_version(pkg: str) -> Optional[str]:
    """
    Resolve latest version for a Homebrew formula or cask using brew CLI JSON v2.
    Works for core, cask, and tap-qualified names (e.g. hashicorp/tap/terraform).
    """
    j = _brew_info_json_v2(pkg, "formula")
    v = _extract_formula_version(j) if j else None
    if v:
        return v

    j = _brew_info_json_v2(pkg, "cask")
    v = _extract_cask_version(j) if j else None
    if v:
        return v

    return None


def update_macos_tools() -> None:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
    tools_path = os.path.join(repo_root, "mac", "bin", "tools.json")

    if not os.path.exists(tools_path):
        raise FileNotFoundError(f"macOS tools.json not found at: {tools_path}")

    if not _brew_exists():
        raise RuntimeError(
            "Homebrew ('brew') not found on PATH. Install Homebrew or run this on a Mac with brew installed."
        )

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
        f.write("\n")

    print(f"macOS tools updated successfully in {tools_path}")


if __name__ == "__main__":
    update_macos_tools()
