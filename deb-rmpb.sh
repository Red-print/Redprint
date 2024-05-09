#!/bin/bash
R='\033[0;31m'
G='\033[0;32m'
P="\033[38;2;217;18;251m"
Y='\033[1;33m'
NC='\033[0m'
ensure_path_format() {
    local path="$1"
    # Add a leading slash if it's not present
    [[ "$path" != /* ]] && path="/$path"
    # Add a trailing slash if it's not present
    [[ "$path" != */ ]] && path="$path/"
    echo "$path"
}
start_uninstall() {
    echo -n "Uninstalling... "
    while :; do
        for s in / - \\ \|; do 
            printf "\rUninstalling... %s" "$s"
            sleep 0.2
        done
    done &
    LOADING_PID=$!
}
stop_uninstall() {
    kill "$LOADING_PID" &>/dev/null
    printf "\r\033[K"
}

echo "Enter the path to the panel directory. Default: /var/www/pterodactyl/"
        read -r PTERO_PANEL

        PTERO_PANEL=${PTERO_PANEL:-/var/www/pterodactyl/} # Use default value if input is empty
        PTERO_PANEL=$(ensure_path_format "$PTERO_PANEL")

        # Check if the panel directory exists
        if [[ ! -d "$PTERO_PANEL" ]]; then
            echo -e "${R}}[!] The panel directory does not exist. Please ensure that the panel directory is correct before running an update.${NC}"
            exit 1
        fi
    # Warning the users
        echo -e "WARNING: ${R}Uninstalling Pterodactyl & Blueprint will delete everything without any possibility of restoring it.${NC}"
        read -p "$(echo -e "${Y}Are you sure you want to continue with the uninstallation? (${G}y${Y}/${R}n${NC}): ")" choice

        case "$choice" in
            y|Y)
            start_uninstall
    sudo rm -rf $PTERO_PANEL &> /dev/null

    # Pteroq queue worker
    sudo rm /etc/systemd/system/pteroq.service &> /dev/null

    # Removing conf files
    sudo unlink /etc/nginx/sites-enabled/pterodactyl.conf &> /dev/null
    stop_uninstall
    read -p "$(echo -e "${Y}Do you want to remove nginx? (${G}y${Y}/${R}n${NC}): ")" choice

    case "$choice" in
        y|Y)
        start_uninstall
        # Stopping nginx
        sudo systemctl stop nginx &> /dev/null

        sudo apt purge nginx nginx-common -y &> /dev/null
        sudo apt autoremove -y &> /dev/null # remove any leftover dependencies
        stop_uninstall
        # Dropping DB & user
        echo -e "${G}Dropping database and user...${NC}"
        mysql -u root -p -e "SHOW DATABASES; DROP DATABASE panel; SELECT User, Host FROM mysql.user; DROP USER 'pterodactyl'@'127.0.0.1';"
        echo -e "${G}Uninstallation process has been completed!${NC}"
                    echo -e "${P}Thanks for using our script!"
            echo -e "If you found it helpful, please consider sharing and/or starring our GitHub repo."
            printf "\n"
                        cat << "EOF"
  ,ad8PPPP88b,     ,d88PPPP8ba,
 d8P"      "Y8b, ,d8P"      "Y8b
dP'           "8a8"           `Yd
8(              "              )8
I8                             8I
 Yb,                         ,dP
  "8a,                     ,a8"
    "8a,                 ,a8"
      "Yba             adP"
        `Y8a         a8P'
          `88,     ,88'
            "8b   d8"  
             "8b d8"   
              `888'
                "
EOF
echo -e "${NC}"
    ;;
        n|N)
        # Dropping DB & user
        echo -e "${G}Dropping database and user...${NC}"
        mysql -u root -p -e "SHOW DATABASES; DROP DATABASE panel; SELECT User, Host FROM mysql.user; DROP USER 'pterodactyl'@'127.0.0.1';"
        echo -e "${G}Uninstallation process has been completed!${NC}"
                    echo -e "${P}Thanks for using our script!"
            echo -e "If you found it helpful, please consider sharing and/or starring our GitHub repo."
            printf "\n"
                        cat << "EOF"
  ,ad8PPPP88b,     ,d88PPPP8ba,
 d8P"      "Y8b, ,d8P"      "Y8b
dP'           "8a8"           `Yd
8(              "              )8
I8                             8I
 Yb,                         ,dP
  "8a,                     ,a8"
    "8a,                 ,a8"
      "Yba             adP"
        `Y8a         a8P'
          `88,     ,88'
            "8b   d8"  
             "8b d8"   
              `888'
                "
EOF
echo -e "${NC}"
        exit
        ;;
        n|N)
        echo "Exiting the script."
        exit
        esac
;;
*)
    echo -e "${Y}Invalid section. Exiting.${NC}"
    exit 1
    ;;
esac