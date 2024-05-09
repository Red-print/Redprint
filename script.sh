#!/bin/bash
R='\033[0;31m'
G='\033[0;32m'
P="\033[38;2;217;18;251m"
Y='\033[1;33m'
NC='\033[0m'
dlr='https://raw.githubusercontent.com/Red-print/Redprint/Redprint-Revamp/'
check_os_type() {
    if [[ -f /etc/redhat-release ]]; then
        OT="rhel"
    elif [[ -f /etc/debian_version ]]; then
        OT="deb"
    else
        echo -e "${R}This OS is not yet supported, Please check our list of supported OS.${NC}"
        exit 1
    fi
}
if (( $(id -u) != 0 )); then
    echo -e "${R}This script must be run as root${NC}"
    exit 1
fi
check_os_type

tm=$(free -tk | awk 'NR==2 {print $2}')
if (( $tm < 2048 )); then
    echo -e "${R}Warning: Less than 2GB of RAM detected. System may not be able to run this.${NC}"
    echo -e "Recommend adding more RAM to the system."
fi

echo -e "${G}Select an option:"
echo -e "1) Install Blueprint"
echo -e "2) Uninstall Blueprint"
echo -e "3) Update Pterodactyl & Blueprint"
echo -e "4) Delete Pterodactyl & Blueprint"

read -p "$(echo -e "${Y}Enter your choice (1-4): ${NC}")" choice

case "$choice" in
    1) bash <(curl -s ${dlr}${OT}-dl.sh) ;;
    2) bash <(curl -s ${dlr}${OT}-rmb.sh) ;;
    3) bash <(curl -s ${dlr}${OT}-up.sh) ;;
    4) bash <(curl -s ${dlr}${OT}-rmpb.sh) ;;
    n|N) echo "Exiting the script."; exit ;;
    *) echo "Invalid choice. Exiting."; exit ;;
esac