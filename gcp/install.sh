#!/bin/bash

SCRIPT_PATH=$(readlink -f "$0" | xargs dirname)
# changing the cwd to the script's containing folder so all paths inside can be local to it
# (important as the script can be called via absolute path and as a nested path)
pushd $SCRIPT_PATH >/dev/null
cd ..

CYAN='\033[0;36m' # Cyan
WHITE='\033[0;37m'  # White

# Install ARP dependencies
echo -e "${CYAN}Creating Python virtual environment...${WHITE}"
python3 -m venv .venv
. .venv/bin/activate
pip install --require-hashes -r app/requirements.txt --no-deps

# generate dActionBoard configuration
echo -e "${CYAN}Generating dActionBoard configuration...${WHITE}"
RUNNING_IN_GCE=true
export RUNNING_IN_GCE   # signaling to run-local.sh that we're running inside GCE (there'll be less questions)
./app/run-local.sh --generate-config-only --validate-google-ads-config

# deploy solution
echo -e "${CYAN}Deploying Cloud components...${WHITE}"
./gcp/setup.sh deploy_public_index deploy_all start

popd >/dev/null
