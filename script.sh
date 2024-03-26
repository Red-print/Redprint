#!/bin/bash

# Define color constants for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check the OS type
check_os_type() {
    if [[ -f /etc/redhat-release ]]; then
        OS_TYPE="rhel"
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
    else
        echo -e "${RED}This OS is not yet supported, Please check our list of supported os.${NC}"
        exit 1
    fi
}

            _URL="https://raw.githubusercontent.com/growtoups/bp-utilities/dev/${OS_TYPE}/${URL}.sh"

# Check for root privileges
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Check OS type and set URLs
check_os_type
set_urls

echo -e "${GREEN}Select an option:"
echo -e "1) Install Blueprint"
echo -e "2) Uninstall Blueprint"
echo -e "3) Update Pterodactyl & Blueprint"
echo -e "4) Deleting Pterodactyl & Blueprint"
read -p "$(echo -e "${YELLOW}Enter your choice (1-4): ${NC}")" choice

case "$choice" in
    1)
    
    URL="install"
    mkdir ./bp-tmp
    cd ./bp-tmp
    wget -q "$_URL" -O ./install.sh
    chmod u+x ./install.sh
source ./install.sh
        rm -f ./install.sh
        ;;
    2)
    URL="uninstall"
    bash <(curl -s $_URL)
        uninstall_blueprint
        ;;
    3)
    URL="update"
    bash <(curl -s $_URL)
        update_pterodactyl_blueprint
        ;;
    4)
    URL="delete"
    bash <(curl -s $_URL)
        delete_pterodactyl_blueprint
        ;;
    *)
        echo "${YELLOW}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac
