#!/usr/bin/env python3
from __future__ import annotations

from collections import defaultdict
from pathlib import Path
from typing import DefaultDict, Dict, List, Sequence, Set, Tuple

END_MARKER = "EOF"

MANAGED_KEYWORD = "neurabytes"
MANAGED_BLOCK_BEGIN = "# --- BEGIN Neurabytes-managed block ---"
MANAGED_BLOCK_END = "# --- END Neurabytes-managed block ---"

AWS_CONFIG_PATH = Path.home() / ".aws" / "config"

import subprocess
import sys
import webbrowser

GITHUB_TOKEN_URL = (
    "https://github.com/settings/tokens/new"
    "?description=Neurabytes%20Dev%20Setup"
    "&scopes=repo%2Cgist%2Cread%3Aorg%2Cworkflow%2Cread%3Auser%2Cuser%3Aemail"
)


def configure_gh_cli() -> None:
    print("\nGitHub CLI authentication & Git credential setup")
    print("-------------------------------------------------\n")

    print("Opening the GitHub token creation page in your default browser...\n")
    webbrowser.open(GITHUB_TOKEN_URL)

    print("If the browser did not open, you can open the URL manually:")
    print(f"   {GITHUB_TOKEN_URL}\n")
    print("Create the token and paste it below.\n")

    try:
        token = input("Paste your GitHub token (leave empty to skip): ").strip()
    except EOFError:
        print("No input received. Skipping gh auth.")
        return

    if not token:
        print("Empty token. Skipping gh auth.")
        return

    print("\nConfiguring gh with your token...\n")

    proc = subprocess.run(
        ["gh", "auth", "login", "--with-token"],
        input=(token + "\n").encode("utf-8"),
        stdout=sys.stdout,
        stderr=sys.stderr,
    )
    if proc.returncode != 0:
        print("gh auth login failed. You may need to run it manually.")
        return

    print("\nSetting gh as Git credential helper...\n")
    proc = subprocess.run(["gh", "auth", "setup-git"], stdout=sys.stdout, stderr=sys.stderr)
    if proc.returncode != 0:
        print("gh auth setup-git failed. You may need to run it manually.")
        return

    print("\nVerifying GitHub CLI authentication...\n")
    subprocess.run(["gh", "auth", "status"])

    print("\nGitHub CLI is authenticated and acting as Git credential helper.\n")

def read_multiline_input(end_marker: str = END_MARKER) -> str:
    """
    Read multi-line input from stdin until a line containing only `end_marker`.
    """
    print("Paste your AWS config content.")
    print(f"Finish by typing a line with only {end_marker} and pressing ENTER.\n")

    lines: List[str] = []
    while True:
        try:
            line = input()
        except EOFError:
            # In case input is piped and ends unexpectedly.
            break

        if line == end_marker:
            break

        lines.append(line)

    return "\n".join(lines)


def parse_aws_config(path: Path) -> Tuple[Sequence[str], Dict[str, List[str]], Sequence[str]]:
    """
    Parse ~/.aws/config into:
      - session_names: sorted list of session names
      - sessions: mapping session_name -> list(profile_names)
      - direct_profiles: sorted list of profile names without an sso_session
    """
    sessions: DefaultDict[str, List[str]] = defaultdict(list)
    known_sessions: Set[str] = set()
    direct_profiles: List[str] = []

    if not path.exists():
        return [], {}, []

    current_type: str | None = None  # 'sso-session', 'profile', or None
    current_name: str | None = None
    current_sso_session: str | None = None

    def flush_section() -> None:
        nonlocal current_type, current_name, current_sso_session

        if not current_name:
            current_type = None
            current_sso_session = None
            return

        if current_type == "sso-session":
            known_sessions.add(current_name)
        elif current_type == "profile":
            if current_sso_session:
                sessions[current_sso_session].append(current_name)
            else:
                direct_profiles.append(current_name)

        current_type = None
        current_name = None
        current_sso_session = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()

        # Skip comments / empty lines
        if not line or line.startswith("#") or line.startswith(";"):
            continue

        # Section header
        if line.startswith("[") and line.endswith("]"):
            flush_section()

            inner = line[1:-1].strip()
            if inner.startswith("sso-session "):
                current_type = "sso-session"
                current_name = inner[len("sso-session ") :].strip()
            elif inner.startswith("profile "):
                current_type = "profile"
                current_name = inner[len("profile ") :].strip()
            else:
                # e.g. [default] -> treat as profile named "default"
                current_type = "profile"
                current_name = inner
            current_sso_session = None
            continue

        # key = value lines
        if "=" in line and current_type is not None:
            key, value = [p.strip() for p in line.split("=", 1)]
            if current_type == "profile" and key == "sso_session":
                current_sso_session = value

    flush_section()

    all_session_names = sorted(set(sessions.keys()) | known_sessions)
    return all_session_names, sessions, sorted(direct_profiles)


def print_summary(
        session_names: Sequence[str],
        sessions: Dict[str, List[str]],
        direct_profiles: Sequence[str],
) -> None:
    index = 1

    for session in session_names:
        print(f"{index}. Session: {session}")
        profiles = sorted(sessions.get(session, []))
        for sub_index, profile in enumerate(profiles, start=1):
            print(f"{index}.{sub_index} Profile: {profile}")
        index += 1

    for profile in direct_profiles:
        print(f"{index}. Direct Profile: {profile}")
        index += 1


def remove_managed_entries(
        path: Path,
        keyword: str = MANAGED_KEYWORD,
        begin_marker: str = MANAGED_BLOCK_BEGIN,
        end_marker: str = MANAGED_BLOCK_END,
) -> None:
    """
    Remove all AWS config sections and managed blocks related to `keyword`.

    Rules:
      - Entire blocks between BEGIN/END managed markers are removed.
      - Any [sso-session ...] or [profile ...] whose name contains `keyword`
        (case-insensitive) is removed.
      - Any section with a line like `sso_session = <something containing keyword>`
        (case-insensitive) is removed.
    """
    if not path.exists():
        # Nothing to clean up.
        return

    keyword_lower = keyword.lower()
    begin_lower = begin_marker.strip().lower()
    end_lower = end_marker.strip().lower()

    lines = path.read_text(encoding="utf-8").splitlines()

    cleaned_lines: List[str] = []
    section_lines: List[str] = []
    remove_section = False
    inside_managed_block = False

    def flush_section() -> None:
        nonlocal section_lines, remove_section
        if section_lines and not remove_section:
            cleaned_lines.extend(section_lines)
        section_lines = []
        remove_section = False

    for raw_line in lines:
        stripped = raw_line.strip()
        lowered = stripped.lower()

        # 1. Handle managed block markers – drop everything inside.
        if lowered == begin_lower:
            flush_section()
            inside_managed_block = True
            continue

        if lowered == end_lower:
            inside_managed_block = False
            continue

        if inside_managed_block:
            # Entire managed block is replaced on each run.
            continue

        # 2. Detect start of a new section.
        if stripped.startswith("[") and stripped.endswith("]"):
            flush_section()

            section_name = stripped[1:-1].strip().lower()
            section_lines = [raw_line]

            # Decide if this section should be removed based on its header.
            if section_name.startswith("sso-session ") and keyword_lower in section_name:
                remove_section = True
            elif section_name.startswith("profile ") and keyword_lower in section_name:
                remove_section = True
            elif section_name == keyword_lower:
                remove_section = True
            else:
                remove_section = False

            continue

        # 3. Lines inside a section (body).
        if section_lines:
            # If a profile uses sso_session that references the keyword, drop the whole section.
            if "sso_session" in lowered and keyword_lower in lowered:
                remove_section = True

            section_lines.append(raw_line)
            continue

        # 4. Anything outside sections and outside managed blocks.
        cleaned_lines.append(raw_line)

    # Final flush for last section.
    flush_section()

    # Write cleaned config back to disk with a trailing newline.
    path.write_text("\n".join(cleaned_lines).rstrip() + "\n", encoding="utf-8")


def append_managed_block(
        path: Path,
        cfg_text: str,
        begin_marker: str = MANAGED_BLOCK_BEGIN,
        end_marker: str = MANAGED_BLOCK_END,
) -> None:
    """
    Append a managed block with clear BEGIN/END markers.
    Ensures we don't add an extra leading blank line when the file is empty.
    """
    path.parent.mkdir(parents=True, exist_ok=True)

    needs_leading_newline = path.exists() and path.stat().st_size > 0

    with path.open("a", encoding="utf-8") as f:
        if needs_leading_newline:
            f.write("\n")

        f.write(begin_marker + "\n")
        f.write(cfg_text.rstrip() + "\n")
        f.write(end_marker + "\n")


def ask_yes_no(question: str) -> bool:
    while True:
        ans = input(f"{question} (yes/no): ").strip().lower()
        if ans in ("y", "yes"):
            return True
        if ans in ("n", "no"):
            return False
        print("Please answer yes or no.")


def main() -> None:
    print("\n=== Neurabytes Environment Setup ===\n")

    # --- Ask if user wants AWS setup ---
    do_aws = ask_yes_no("Do you want to set up AWS configuration?")
    if do_aws:
        # 1. Read multi-line input for NEW managed block content.
        cfg_text = read_multiline_input()

        if not cfg_text.strip():
            print("\nNo config content provided. Exiting without modifying ~/.aws/config.")
        else:
            aws_config_path = AWS_CONFIG_PATH
            aws_config_path.parent.mkdir(parents=True, exist_ok=True)

            # 2. Show summary of CURRENT config (if it exists).
            if aws_config_path.exists():
                print("\nCurrent config summary (before cleanup):\n")
                session_names, sessions, direct_profiles = parse_aws_config(aws_config_path)
                print_summary(session_names, sessions, direct_profiles)
            else:
                print(f"\nConfig file does not exist yet: {aws_config_path}")

            # 3. Remove all managed entries (idempotent behavior).
            remove_managed_entries(aws_config_path)

            # 4. Append new managed block.
            append_managed_block(aws_config_path, cfg_text)
            print(f"\nAppended new {MANAGED_KEYWORD.capitalize()} block to: {aws_config_path}\n")

            # 5. Show summary of FINAL config.
            print("Final config summary (after update):\n")
            session_names, sessions, direct_profiles = parse_aws_config(aws_config_path)
            print_summary(session_names, sessions, direct_profiles)

    else:
        print("\nSkipping AWS setup.\n")

    # --- Ask if user wants GitHub setup ---
    do_github = ask_yes_no("Do you want to configure GitHub CLI authentication?")
    if do_github:
        configure_gh_cli()
    else:
        print("\nSkipping GitHub setup.\n")

    print("\n=== Setup Complete ===\n")



if __name__ == "__main__":
    main()
