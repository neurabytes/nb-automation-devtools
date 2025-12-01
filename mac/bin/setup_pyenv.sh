#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this as root/sudo."
  exit 1
fi

# Initialize pyenv for this session
eval "$(pyenv init -)"

# Install Python
pyenv install -s 3.11.6
pyenv global 3.11.6

python3 --version

pip install --upgrade pip
pip install pipenv pre-commit

echo "Setup complete."
