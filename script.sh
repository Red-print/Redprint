#!/bin/bash

# Define color constants for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to ensure correct path format
ensure_path_format() {
    local path="$1"
    # Add a leading slash if it's not present
    [[ "$path" != /* ]] && path="/$path"
    # Add a trailing slash if it's not present
    [[ "$path" != */ ]] && path="$path/"
    echo "$path"
}

# Function for loading animation
start_loading() {
    echo -n "Installing Dependencies... "
    while :; do
        for s in / - \\ \|; do 
            printf "\rInstalling Dependencies... %s" "$s"
            sleep 0.2
        done
    done &
    LOADING_PID=$!
}

# Function to stop loading animation
stop_loading() {
    kill "$LOADING_PID" &>/dev/null
    printf "\r\033[K"
}

# Check for root privileges
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

echo -e "${GREEN}Select an option:"
echo -e "1) Install Blueprint"
echo -e "2) Uninstall Blueprint${NC}"
read -p "$(echo -e "${YELLOW}Enter your choice (1 or 2): ${NC}")" choice

case "$choice" in
    1)
        echo "Enter the path to the panel directory. By default its : /var/www/pterodactyl"
        read -r PTERO_PANEL

        PTERO_PANEL=$(ensure_path_format "$PTERO_PANEL")

        # Check if the panel directory exists
        if [[ ! -d "$PTERO_PANEL" ]]; then
            echo -e "${RED}[!] The panel directory does not exist. Please ensure that the panel directory is correct before running Blueprint.${NC}"
            exit 1
        fi

        start_loading

        # Installing dependencies
        sudo apt-get install -y ca-certificates curl gnupg &> /dev/null
        sudo mkdir -p /etc/apt/keyrings &> /dev/null
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes &> /dev/null
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list &> /dev/null
        sudo apt-get update &> /dev/null
        sudo apt-get install -y nodejs &> /dev/null
        sudo npm i -g yarn &> /dev/null

        stop_loading

        cd "$PTERO_PANEL" || exit

        # Yarn install with silent mode to reduce output noise
        yarn install --silent

        IS_MODIFIED=false
        if diff -q <(curl -s https://raw.githubusercontent.com/pterodactyl/panel/develop/routes/admin.php) "${PTERO_PANEL}routes/admin.php" &> /dev/null; then
            IS_MODIFIED=true
        fi
        if diff -q <(curl -s https://raw.githubusercontent.com/pterodactyl/panel/develop/resources/scripts/routers/routes.ts) "${PTERO_PANEL}resources/scripts/routers/routes.ts" &> /dev/null; then
            IS_MODIFIED=true
        fi

        if [[ $IS_MODIFIED == "true" ]]; then
            echo -e "${RED}[!] Blueprint has detected that the panel has been modified. Please ensure that the panel is not modified before running Blueprint.${NC}"
            exit 1
        fi

        # Validate and handle the download URL securely
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/teamblueprint/main/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)
        if [[ -n $DOWNLOAD_URL ]]; then
            wget "$DOWNLOAD_URL" -O latest_release.zip &> /dev/null
            unzip -o latest_release.zip &> /dev/null
            chmod +x blueprint.sh
            ./blueprint.sh
        else
            echo -e "${RED}[!] Failed to retrieve the latest release of Blueprint. Please check your internet connection and try again.${NC}"
            exit 1
        fi
        ;;
    2)
        echo -e "WARNING!: ${RED}The following uninstall will remove blueprint and most* of its components."
        echo -e "This will also delete your app/, public/, resources/, and ./blueprint folders.${NC}"
        read -p "$(echo -e "${YELLOW}Are you sure you want to continue with the uninstall${NC} (${GREEN}y${YELLOW}/${RED}n${NC}): ")" choice

        case "$choice" in
            y|Y) 
                echo "Continuing with the uninstallation..."
                ;;
            n|N) 
                echo "Exiting the script."
                exit
                ;;
            *) 
                echo -e "${YELLOW}Invalid choice. Please enter 'y' for yes or 'n' for no.${NC}"
                exit 1
                ;;
        esac

        # Define variables and proceed with the uninstallation
        directory="$PTERO_PANEL"
        files_to_delete=(
            ".blueprint/"
            "app/"
            "public/"
            "resources/"
            "routes/"
            "blueprint.sh"
        )

        read -p "$(echo -e "${YELLOW}Current directory: $directory. Press Enter to confirm, or enter a new directory: ${NC}")" new_directory

        if [[ -n "$new_directory" ]]; then
            directory="$new_directory"
            echo "Pterodactyl directory changed to: $directory"
        else
            echo "Pterodactyl directory confirmed: $directory"
        fi

        currentLoc=$(pwd)
        cd "$directory" || exit
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

        read -p "$(echo -e "${YELLOW}Do you want to update your database schema for the newest version of Pterodactyl? (${GREEN}y${YELLOW}/${RED}n${NC}): ")" choice

        case "$choice" in
            y|Y) 
                echo "Updating database schema..."
                php artisan migrate --seed --force
                ;;
            n|N) 
                echo "Skipping database schema update."
                ;;
            *) 
                echo "${YELLOW}Invalid choice.${NC}"
                exit 1
                ;;
        esac

        echo -e "${GREEN}Finishing up...${NC}"
        chown -R www-data:www-data "$directory"
        php artisan queue:restart
        php artisan up
        chown -R www-data:www-data "$directory"
        echo "If you want to update your dependencies also, run:"
        echo "composer install --no-dev --optimize-autoloader"
        echo "As composer's recommendation, do NOT run it as root."
        echo "See https://getcomposer.org/root for details."
        cd "$currentLoc"
        echo -e "${GREEN}Uninstallation and update process completed!${NC}"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
