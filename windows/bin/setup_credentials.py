#!/usr/bin/env python3
from pathlib import Path
from collections import defaultdict


END_MARKER = "EOF"


def read_multiline_input(end_marker: str = END_MARKER) -> str:
    print("Paste your AWS config content.")
    print(f"Finish by typing a line with only {end_marker} and pressing ENTER.\n")

    lines = []
    while True:
        try:
            line = input()
        except EOFError:
            break  # in case input is piped and ends unexpectedly

        if line == end_marker:
            break

        lines.append(line)

    return "\n".join(lines)


def parse_aws_config(path: Path):
    """
    Parse ~/.aws/config into:
      - sessions: { session_name: [profile_names...] }
      - direct_profiles: [profile_names_without_sso_session]
    """
    sessions = defaultdict(list)  # session_name -> list(profile_name)
    known_sessions = set()
    direct_profiles = []

    current_type = None   # 'sso-session' or 'profile' or None
    current_name = None   # session/profile name
    current_sso_session = None

    def flush_section():
        nonlocal current_type, current_name, current_sso_session

        if not current_name:
            return

        if current_type == "sso-session":
            known_sessions.add(current_name)

        elif current_type == "profile":
            if current_sso_session:
                sessions[current_sso_session].append(current_name)
            else:
                direct_profiles.append(current_name)

        # reset section-specific state
        current_type = None
        current_name = None
        current_sso_session = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()

        # skip comments / empty lines
        if not line or line.startswith("#") or line.startswith(";"):
            continue

        if line.startswith("[") and line.endswith("]"):
            # new section starts -> flush previous
            flush_section()

            inner = line[1:-1].strip()

            if inner.startswith("sso-session "):
                current_type = "sso-session"
                current_name = inner[len("sso-session ") :]

            elif inner.startswith("profile "):
                current_type = "profile"
                current_name = inner[len("profile ") :]

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

    # flush last section
    flush_section()

    # union so we also list sessions that only appear via profiles
    all_session_names = sorted(set(sessions.keys()) | known_sessions)

    return all_session_names, sessions, sorted(direct_profiles)


def print_summary(session_names, sessions, direct_profiles):
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

def remove_neurabytes_entries(path: Path, keyword: str = "neurabytes"):
    """
    Remove all AWS config sections related to 'neurabytes'.
    Also removes comment markers:
      - # --- BEGIN Neurabytes-managed block ---
      - # --- END Neurabytes-managed block ---
    """

    if not path.exists():
        print(f"Config file not found: {path}")
        return

    lines = path.read_text(encoding="utf-8").splitlines()

    cleaned_lines = []
    remove_section = False

    current_section_lines = []

    begin_marker = f"# --- BEGIN {keyword.capitalize()}-managed block ---".lower()
    end_marker   = f"# --- END {keyword.capitalize()}-managed block ---".lower()

    def flush_section():
        nonlocal cleaned_lines, remove_section, current_section_lines
        if not remove_section:
            cleaned_lines.extend(current_section_lines)
        current_section_lines = []

    for line in lines:
        stripped = line.strip()

        # ---------------------------------------------------------
        # 1. Remove comment markers like:
        #    # --- BEGIN Neurabytes-managed block ---
        #    # --- END Neurabytes-managed block ---
        # ---------------------------------------------------------
        if stripped.lower() == begin_marker or stripped.lower() == end_marker:
            # skip the comment entirely
            continue

        # ---------------------------------------------------------
        # 2. Detect start of a section
        # ---------------------------------------------------------
        if stripped.startswith("[") and stripped.endswith("]"):

            # flush previous
            if current_section_lines:
                flush_section()

            section_name = stripped[1:-1].strip().lower()
            current_section_lines = [line]

            # remove sso-session neurabytes
            if section_name.startswith("sso-session ") and keyword in section_name:
                remove_section = True

            # remove profiles with neurabytes in the name
            elif section_name.startswith("profile ") and keyword in section_name:
                remove_section = True

            # remove [neurabytes] if it exists
            elif section_name == keyword:
                remove_section = True

            else:
                remove_section = False

            continue

        # ---------------------------------------------------------
        # 3. Inside a section
        # ---------------------------------------------------------
        if current_section_lines:
            # profile with: sso_session = neurabytes
            if "sso_session" in stripped.lower() and keyword in stripped.lower():
                remove_section = True

            current_section_lines.append(line)
            continue

        # ---------------------------------------------------------
        # 4. Anything outside sections (should normally not happen)
        # ---------------------------------------------------------
        cleaned_lines.append(line)

    # final flush
    if current_section_lines:
        flush_section()

    # ---------------------------------------------------------
    # Write cleaned config back to disk
    # ---------------------------------------------------------
    path.write_text("\n".join(cleaned_lines).rstrip() + "\n", encoding="utf-8")

    print(f"Removed all sections and comments related to '{keyword}'. Cleaned config saved.")


def main():
    # 1. Read multi-line input for NEW neurabytes block
    cfg_text = read_multiline_input()

    aws_config_path = Path.home() / ".aws" / "config"
    aws_config_path.parent.mkdir(parents=True, exist_ok=True)

    # 2. Show summary of CURRENT config (if it exists)
    if aws_config_path.exists():
        print("\nCurrent config summary (before cleanup):\n")
        session_names, sessions, direct_profiles = parse_aws_config(aws_config_path)
        print_summary(session_names, sessions, direct_profiles)
    else:
        print(f"\nConfig file does not exist yet: {aws_config_path}")

    # 3. Remove neurabytes entries to add a clean installation
    remove_neurabytes_entries(aws_config_path)

    # 4. Append new neurabytes block with clear begin/end comments
    begin_marker = "# --- BEGIN Neurabytes-managed block ---"
    end_marker = "# --- END Neurabytes-managed block ---"

    with aws_config_path.open("a", encoding="utf-8") as f:
        f.write("\n" + begin_marker + "\n")
        f.write(cfg_text.rstrip() + "\n")
        f.write(end_marker + "\n")

    print(f"\nAppended new Neurabytes block to: {aws_config_path}\n")

    # 5. Show summary of FINAL config
    print("Final config summary (after update):\n")
    session_names, sessions, direct_profiles = parse_aws_config(aws_config_path)
    print_summary(session_names, sessions, direct_profiles)



if __name__ == "__main__":
    main()
