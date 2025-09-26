#!/usr/bin/env python3
"""Automation script for managing development environment and tools.

This script serves as a bridge between the Makefile and the DevOps automation tools.
It provides a command-line interface to manage various development tasks:

1. Repository Management:
   - 'setup': Clones or updates the DevOps automation repository
   - Handles GitHub authentication and dependency installation

2. Script Execution:
   - 'run': Executes scripts in the DevOps environment through pipenv
   - Example: python automation.py run frontend test
   - Example: python automation.py run terraform plan
   - Supports multiple components:
     * Frontend: test, format, lint, run, build
     * Backend: test, format, lint, run, build
     * Terraform: init, validate, plan, apply, destroy

The Makefile provides convenient shortcuts to these commands, allowing developers
to run commands like 'make frontend-test' or 'make terraform-apply' which are
internally translated to appropriate calls to this automation script.

Usage:
    python automation.py <command> [args...]
    
For detailed documentation, visit: https://github.com/neurabytes/nb-automation-devtools
"""

import os
import sys
import json
import logging
import subprocess
from pathlib import Path
from typing import Optional, Tuple, List, Dict, Any
from urllib import request
from urllib.error import URLError

# Constants
GITHUB_API_URL = "https://api.github.com/user"
DOCS_URL = "https://github.com/neurabytes/nb-automation-devtools"
SCRIPT_REPO_URL = "https://github.com/neurabytes/nb-infrastructure-devops-automation.git"
SCRIPT_REPO_DIR = ".build/devops-automation"

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("automation")

def run_command(cmd: List[str], cwd: Optional[str] = None) -> Tuple[int, str, str]:
    """Run a command and return exit code, stdout, and stderr."""
    try:
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate()
        return process.returncode, stdout, stderr
    except Exception as e:
        return 1, "", str(e)

def get_validated_github_token() -> Optional[str]:
    """Get and validate GitHub token from environment."""
    try:
        token = os.environ.get('CUSTOM_GITHUB_TOKEN')
        if not token:
            logger.error(f"GitHub token not found in environment variable 'CUSTOM_GITHUB_TOKEN'. Read the Readme on {DOCS_URL}")
            return None
        
        headers = {
            'Authorization': f'token {token}',
            'User-Agent': 'Python'
        }
        req = request.Request(GITHUB_API_URL, headers=headers)
        with request.urlopen(req) as response:
            if response.getcode() == 200:
                logger.info("GitHub token validated successfully")
                return token
            
        logger.error(f"The GitHub token is invalid or does not have the required permissions. Read the Readme on {DOCS_URL}")
        return None
    except URLError as e:
        logger.error(f"The GitHub token is invalid or does not have the required permissions. Read the Readme on {DOCS_URL}")
        logger.warning(f"Error details: {str(e)}")
        return None

def create_auth_url(repo_url: str, token: str) -> str:
    """Create authenticated URL with token."""
    return repo_url.replace('https://', f'https://{token}@')

def install_dependencies(repo_dir: str) -> bool:
    """Install project dependencies using pipenv."""
    try:
        logger.info("Setting up Python environment...")
        
        # Check if pipenv is installed
        exit_code, stdout, stderr = run_command(['pip', 'show', 'pipenv'])
        if exit_code != 0:
            logger.info("Pipenv not found. Installing pipenv...")
            exit_code, stdout, stderr = run_command(['pip', 'install', 'pipenv'])
            if exit_code != 0:
                logger.error(f"Failed to install pipenv: {stderr}")
                return False
            logger.info("Pipenv installed successfully")

        # Install dependencies using pipenv
        logger.info("Installing project dependencies...")
        exit_code, stdout, stderr = run_command(['pipenv', 'install'], cwd=repo_dir)
        if exit_code != 0:
            logger.error(f"Pipenv install failed: {stderr}")
            return False

        return True
    except Exception as e:
        logger.error(f"Failed to install dependencies: {str(e)}")
        return False

def clone_update_repo(repo_url: str, repo_dir: str, token: str) -> bool:
    """Clone or update the repository."""
    try:
        auth_repo_url = create_auth_url(repo_url, token)
        repo_path = Path(repo_dir)
        repo_path.parent.mkdir(parents=True, exist_ok=True)

        if not repo_path.exists():
            logger.info("Downloading DevOps scripts...")
            exit_code, stdout, stderr = run_command(['git', 'clone', auth_repo_url, repo_dir])
            if exit_code != 0:
                logger.error(f"Git clone failed: {stderr}")
                return False
            logger.info("Download completed successfully")
        else:
            logger.info("Updating DevOps scripts...")
            exit_code, stdout, stderr = run_command(['git', 'reset', '--hard'], cwd=repo_dir)
            if exit_code == 0:
                exit_code, stdout, stderr = run_command(['git', 'pull'], cwd=repo_dir)
            if exit_code != 0:
                logger.error(f"Git pull failed: {stderr}")
                return False
            logger.info("Update completed successfully")

        return True
    except Exception as e:
        logger.error(f"Failed to clone/update repository: {str(e)}")
        return False

def setup_repository() -> bool:
    """Set up or update the repository."""
    try:
        # Step 1: Get GitHub token
        token = get_validated_github_token()
        if not token:
            return False

        # Step 2: Clone or update repository
        success = clone_update_repo(SCRIPT_REPO_URL, SCRIPT_REPO_DIR, token)
        if not success:
            return False

        # Step 3: Install dependencies
        success = install_dependencies(SCRIPT_REPO_DIR)
        if not success:
            return False

        logger.info("Setup completed successfully")
        return True

    except Exception as e:
        logger.error(f"An error occurred: {str(e)}")
        return False

def run_devops_script(input_command: list[str]) -> bool:
    """Run a script through the devops environment."""
    try:
        logger.info(f"Running command: {' '.join(input_command)}")

        # Force pipenv to create its own environment and suppress warnings
        os.environ['PIPENV_VERBOSITY'] = '-1'
        
        # Print pipenv information
        result = subprocess.run(['pipenv', '--venv'], capture_output=True, text=True)
        if result.returncode == 0:
            pipenv_env = result.stdout.strip()
            logger.info(f"Using virtual environment: {pipenv_env}")

        current_directory = os.getcwd()
        
        # Change to the devops directory and run through pipenv
        os.chdir(SCRIPT_REPO_DIR)
        
        run_cmd = f'pipenv run python scripts/main.py {" ".join(input_command)}'
        result = os.system(run_cmd)
        
        # Reset working directory
        os.chdir(current_directory)
        
        return result == 0
    except Exception as e:
        logger.error(f"Failed to run script: {str(e)}")
        return False

def print_usage() -> None:
    """Print script usage information."""
    print("""
Usage: python automation.py <command> [args...]

Commands:
    setup               Set up or update the repository
    run <script>        Run a script through the devops environment
    help               Show this help message

Examples:
    python automation.py setup
    python automation.py run terraform init
    """)

def main() -> int:
    """Main entry point for the script."""
    if len(sys.argv) < 2 or sys.argv[1] == "help":
        print_usage()
        return 0

    command = sys.argv[1]

    if command == "setup":
        return 0 if setup_repository() else 1
    elif command == "run":
        if len(sys.argv) < 3:
            logger.error("Missing script name")
            print_usage()
            return 1
        return 0 if run_devops_script(sys.argv[2:]) else 1
    else:
        logger.error(f"Unknown command: {command}")
        print_usage()
        return 1

if __name__ == "__main__":
    sys.exit(main()) 