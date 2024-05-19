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
start_uloading() {
    echo -n "Updating... "
    while :; do
        for s in / - \\ \|; do 
            printf "\rUpdating Dependencies... %s" "$s"
            sleep 0.2
        done
    done &
    LOADING_PID=$!
}
stop_uloading() {
    kill "$LOADING_PID" &>/dev/null
    printf "\r\033[K"
}
echo "Enter the path to the panel directory. Default: /var/www/pterodactyl/"
    read -r PTERO_PANEL

    PTERO_PANEL=${PTERO_PANEL:-/var/www/pterodactyl/} # Use default value if input is empty
    PTERO_PANEL=$(ensure_path_format "$PTERO_PANEL")

    # Check if the panel directory exists
    if [[ ! -d "$PTERO_PANEL" ]]; then
        echo -e "${RED}[!] The panel directory does not exist. Please ensure that the panel directory is correct before running an update.${NC}"
        exit 1
    fi
# Warning the users
    echo -e "WARNING: ${R}Updating will make Pterodactyl unavailable. Please note that you WILL need to reinstall your blueprint extensions."
    read -p "$(echo -e "${Y}Are you sure you want to continue with the update? (${G}y${Y}/${R}n${NC}): ")" choice

    case "$choice" in
        y|Y)
            echo -e "${G}Pterodactyl is now in maintenance mode.${NC}"
            cd "$PTERO_PANEL" || exit # Safeguard against directory change failure
            php artisan down

            echo -e "${G}Downloading the latest version of Pterodactyl...${NC}"
            curl -L -s https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xz

            chmod -R 755 storage/* bootstrap/cache

            echo -e "${G}Updating Dependencies...${NC}"
            start_uloading
            composer install --no-dev --optimize-autoloader --quiet
            stop_uloading

            echo -e "${G}Clearing views and configs...${NC}"
            php artisan view:clear
            php artisan config:clear
            php artisan migrate -q --seed --force

            echo -e "${G}Setting up Web Server Permissions...${NC}"
            chown -R nginx:nginx "${PTERO_PANEL}"*

            echo -e "${G}Restarting Workers...${NC}"
            php artisan queue:restart

            echo -e "${G}Pterodactyl is now back online.${NC}"
            php artisan up

            blueprint -upgrade remote blueprintframework/fallback

            read -p "$(echo -e "${Y}Do you want to reinstall blueprint extensions? \n${R}[!] Do note that there can be breaking changes.${NC} (${G}y${Y}/${R}n${NC}): ")" reinstall_choice

case "$reinstall_choice" in
    y|Y)
        echo -e "${G}Enter the extensions you want to reinstall (separate with commas, e.g., nebula,slate):${NC}"
        read -r extensions

        IFS=',' read -ra EXT_ARRAY <<< "$extensions"
        for ext in "${EXT_ARRAY[@]}"; do
            ext=$(echo "$ext" | xargs) # Trim whitespace
            blueprint_file="${PTERO_PANEL}/${ext}.blueprint"

            if [[ -f "$blueprint_file" ]]; then
                echo -e "${G}Reinstalling blueprint extension: $ext...${NC}"
                blueprint -install ${ext}
            else
                echo -e "${R}[!] Blueprint file not found for extension: $ext${NC}"
            fi
        done
        ;;
    n|N)
        echo "Skipping blueprint extensions reinstallation."
        ;;
    *)
        echo "Invalid choice. Skipping blueprint extensions reinstallation."
        ;;
esac
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
            echo "Exiting the script."
            exit 1
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
