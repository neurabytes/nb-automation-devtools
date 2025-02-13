# Commons Directory Documentation

This documentation explains the contents and usage of the `commons` directory only. For full repository documentation, please refer to the root README.md.

## Purpose
The `commons` directory contains reusable code that we want to share across multiple repositories. Instead of duplicating code, we maintain it here and distribute it to other repositories as needed.

## Repository Organization
1. `commons/`: 
   - Contains all shared code that will be distributed to other repositories
   - These files will be copied and committed to other repositories

2. Other Directories:
   - Contain reusable automation code that stays in this repository
   - Are cloned temporarily when running Makefile commands
   - Are not committed to other repositories
   - Can be updated with new features independently

## Directory Contents
- `.build/`: Repository setup scripts
  - `ensure-scripts-repo.ps1`: Windows setup script
  - `ensure-scripts-repo.sh`: Unix setup script
- `Makefile`: Shared build commands for all repositories

## How Distribution Works
1. Files in the `commons` directory are identified for sharing
2. Our automation tools copy these files to other repositories
3. Only files from `commons` are committed to other repositories
4. When you run Makefile commands, other directories are temporarily cloned as needed

## Next Steps
We are developing an automation script that will:
1. Scan through our repositories
2. Copy the relevant files from this `commons` folder
3. Commit only the necessary shared code to each repository