#!/bin/bash

START_TIME=$(date +%s)
LOGFILE="/var/log/xalora-install.log"
WORKDIR="/tmp/Xalora-install"
VERSION="3.1"

BLUE='\033[0;94m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

mkdir -p "$WORKDIR"
exec 3>&1
exec 4>&2
exec 1> >(tee -a "$LOGFILE") 2>&1

trap 'cleanup; exit 1' INT TERM

check_existing_installation() {
    local component=$1
    local directory=$2
    
    if [ -d "$directory" ]; then
        echo -e "${YELLOW}Warning: $component directory ($directory) already exists.${NC}"
        while true; do
            read -p "Do you want to continue with the installation? This may overwrite existing files [y/N]: " response
            case $response in
                [Yy]* )
                    log "User chose to continue installation despite existing $component directory"
                    return 0
                    ;;
                [Nn]* | "" )
                    log "User chose to abort installation due to existing $component directory"
                    echo -e "${RED}Installation aborted by user${NC}"
                    return 1
                    ;;
                * )
                    echo "Please answer y or n"
                    ;;
            esac
        done
    fi
    return 0
}

elapsed_time() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(( (elapsed % 3600) / 60 ))
    local seconds=$((elapsed % 60))
    printf "${BLUE}Time Elapsed: %02d:%02d:%02d${NC}\n" $hours $minutes $seconds
}

show_banner() {
    clear
    cat << "EOF"

 __   __     _                 _____            _     
 \ \ / /    | |               |  __ \          | |    
  \ V / __ _| | ___  _ __ __ _| |  | | __ _ ___| |__  
   > < / _` | |/ _ \| '__/ _` | |  | |/ _` / __| '_ \ 
  / . \ (_| | | (_) | | | (_| | |__| | (_| \__ \ | | |
 /_/ \_\__,_|_|\___/|_|  \__,_|_____/ \__,_|___/_| |_|
                                                      
                                                      
EOF
    echo -e "\n${BOLD}Xalora Installer v${VERSION}${NC}\n"
    echo -e "\n${BOLD}script by Vspcoder software from XaloraLabs${NC}\n"
    echo -e "\n${BOLD}All rights reserved${NC}\n"
    elapsed_time
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

execute_step() {
    local cmd="$1"
    local msg="$2"
    
    echo -e "${BLUE}$msg${NC}"
    log "Executing: $msg"
    
    if eval "$cmd" &>> "$LOGFILE"; then
        echo -e "${GREEN}✓ Complete${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}\n"
        return 1
    fi
}

cleanup() {
    echo -e "${BLUE}Cleaning up temporary files${NC}"
    rm -rf "$WORKDIR"
}

check_dependencies() {
    local deps=("curl" "git" "node" "npm" "docker")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing+=($dep)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${BLUE}Missing dependencies: ${missing[*]}${NC}"
        return 1
    fi
    return 0
}

install_dependencies() {
    echo -e "\n${BOLD}Installing Dependencies${NC}"
    
    execute_step "mkdir -p /etc/apt/keyrings" "Setting up keyrings directory"
    execute_step "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg" "Adding NodeSource repository"
    execute_step "echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main' | tee /etc/apt/sources.list.d/nodesource.list" "Configuring NodeSource"
    execute_step "apt-get update" "Updating package lists"
    execute_step "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs git curl" "Installing Node.js and Git"
    execute_step "curl -sSL https://get.docker.com/ | CHANNEL=stable bash" "Installing Docker"
    
    if check_dependencies; then
        return 0
    else
        return 1
    fi
}

install_panel() {
    echo -e "\n${BOLD}Installing Xalora Dash${NC}"
    
    # Check if panel directory exists
    if ! check_existing_installation "Panel" "/var/www/XaloraClient"; then
        return 1
    fi
    
    # Clone and setup panel
    execute_step "cd /var && git clone https://github.com/XaloraLabs/XaloraClient.git" "Cloning Panel repository"
    execute_step "cd /var/www/XaloraClient && npm install" "Installing Panel dependencies"
    execute_step "cd /var/www/XaloraClient && npm run build" "Building Panel"
    
    if [ -d "/var/www/XaloraClient" ]; then
        return 0
    else
        return 1
    fi
}
    
    execute_step "cd /var/www/XaloraClient && pm2 start npm --name xalora-panel -- run start" "Starting dash service"
    execute_step "pm2 startup && pm2 save" "Setting up autostart"
}

remove_
