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

echo -e "WARNING!: ${R}The following uninstall will remove blueprint and most* of its components."
        echo -e "This will also delete your app/, public/, resources/, and ./blueprint folders.${NC}"
        read -p "$(echo -e "${Y}Are you sure you want to continue with the uninstall${NC} (${G}y${Y}/${R}n${NC}): ")" choice

        case "$choice" in
            y|Y) 
                echo "Continuing with the uninstallation..."
                ;;
            n|N) 
                echo "Exiting the script."
                exit
                ;;
            *) 
                echo -e "${Y}Invalid choice. Please enter 'y' for yes or 'n' for no.${NC}"
                exit 1
                ;;
        esac

        # Define variables and proceed with the uninstallation
        PTERO_PANEL=${PTERO_PANEL:-/var/www/pterodactyl/} # Use default value if input is empty
        PTERO_PANEL=$(ensure_path_format "$PTERO_PANEL")
        files_to_delete=(
            ".blueprint/"
            "app/"
            "public/"
            "resources/"
            "routes/"
            "blueprint.sh"
        )
echo "Enter the path to the panel directory. default : /var/www/pterodactyl/"
        read -r PTERO_PANEL


        # Check if the panel directory exists
        if [[ ! -d "$PTERO_PANEL" ]]; then
            echo -e "${R}[!] The panel directory does not exist. Please ensure that the panel directory is correct before running the uninstallation script.${NC}"
            exit 1
        fi
        currentLoc=$(pwd)
        cd "$PTERO_PANEL" || exit
        php artisan down
        echo "Set panel into Maintenance Mode"

        # Iterate over each filename and delete it
        for filename in "${files_to_delete[@]}"; do
            if [[ -e "$filename" ]]; then
                rm -r "$filename"
                echo "Deleted '$filename'."
            else
                echo "File '$filename' does not exist."
            fi
        done

        echo "Deleting files completed."
        curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv
        echo "Latest Pterodactyl panel downloaded and extracted."
        rm -f panel.tar.gz
        chmod -R 755 storage/* bootstrap/cache
        php artisan view:clear
        php artisan config:clear

        read -p "$(echo -e "${Y}Do you want to update your database schema for the newest version of Pterodactyl? (${G}y${Y}/${R}n${NC}): ")" choice

        case "$choice" in
            y|Y) 
                echo "Updating database schema..."
                php artisan migrate -q --seed --force
                ;;
            n|N) 
                echo "Skipping database schema update."
                ;;
            *) 
                echo "${Y}Invalid choice.${NC}"
                exit 1
                ;;
        esac

        echo -e "${G}Finishing up...${NC}"
        chown -R www-data:www-data "$PTERO_PANEL"
        php artisan queue:restart
        php artisan up
        chown -R www-data:www-data "$PTERO_PANEL"
        echo "If you want to update your dependencies also, run:"
        echo "composer install --no-dev --optimize-autoloader"
        echo "As composer's recommendation, do NOT run it as root."
        echo "See https://getcomposer.org/root for details."
        cd "$currentLoc"
        echo -e "${G}Uninstallation and update process completed!${NC}"
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
