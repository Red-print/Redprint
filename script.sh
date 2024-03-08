#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
# Check if the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}" 1>&2
    exit 1
fi

echo -e "Select an option:"
echo -e "${GREEN}1) Install Blueprint${NC}"
echo -e "${RED}2) Uninstall Blueprint${NC}"
read -p "$(echo -e "${YELLOW}Enter your choice (${GREEN}1${NC} ${YELLOW}or${NC} ${RED}2${NC}): ")" choice

case "$choice" in
1)
echo -e "${GREEN}Starting installation process...${NC}"
    echo -e "${GREEN}Installing necessary packages: ca-certificates, curl, gnupg...${NC}"
    sudo apt-get install -y ca-certificates curl gnupg

    echo -e "${GREEN}Creating /etc/apt/keyrings directory...${NC}"
    sudo mkdir -p /etc/apt/keyrings

    echo -e "${GREEN}Adding NodeSource GPG key...${NC}"
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    echo -e "${GREEN}Adding NodeSource repository...${NC}"
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

    echo -e "${GREEN}Updating package lists...${NC}"
    sudo apt-get update

    echo -e "${GREEN}Installing Node.js...${NC}"
    sudo apt-get install -y nodejs

    echo -e "${GREEN}Installing Yarn globally...${NC}"
    sudo npm i -g yarn

    echo -e "${GREEN}Changing directory to /var/www/pterodactyl...${NC}"
    cd /var/www/pterodactyl || exit

    echo -e "${GREEN}Installing dependencies with Yarn...${NC}"
    yarn

    echo -e "${GREEN}Downloading the latest release of teamblueprint/main...${NC}"
    wget $(curl -s https://api.github.com/repos/teamblueprint/main/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4) -O latest_release.zip

    echo -e "${GREEN}Unzipping the latest release...${NC}"
    unzip -o latest_release.zip

    echo -e "${GREEN}Making blueprint.sh executable...${NC}"
    chmod +x blueprint.sh

    echo -e "${GREEN}Executing blueprint.sh...${NC}"
    ./blueprint.sh
    ;;
2)
    # Uninstallation process
    echo -e "WARNING!: ${RED}The following uninstall will remove blueprint and most* of its components."
    echo -e "${RED}This will also delete your app/, public/, resources/, and ./blueprint folders.${NC}"
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
    directory="/var/www/pterodactyl"
    files_to_delete=(
        ".blueprint/"
        "app/"
        "public/"
        "resources/"
        "routes/"
        "blueprint.sh"
    )

    read -p "$(echo -e "${YELLOW}Current directory: $directory. Press Enter to confirm, or enter a new directory: ${NC}")" new_directory

    if [ -n "$new_directory" ]; then
        directory="$new_directory"
        echo "Pterodactyl directory changed to: $directory"
    else
        echo "Pterodactyl directory confirmed: $directory"
    fi

    currentLoc=$(pwd)
    cd $directory || exit
    php artisan down
    echo "Set panel into Maintenance Mode"

    # Iterate over each filename and delete it
    for filename in "${files_to_delete[@]}"; do
        if [ -e "$filename" ]; then
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
    chown -R www-data:www-data $directory
    php artisan queue:restart
    php artisan up
    chown -R www-data:www-data $directory
    echo "If you want to update your dependencies also, run:"
    echo "composer install --no-dev --optimize-autoloader"
    echo "As composer's recommendation, do NOT run it as root."
    echo "See https://getcomposer.org/root for details."
    cd $currentLoc
    echo -e "${GREEN}Uninstallation and update process completed!${NC}"
    ;;
*)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac
