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

stop_loading() {
    kill "$LOADING_PID" &>/dev/null
    printf "\r\033[K"
}
case "$choice" in
1)
    read -r -p "Enter the path to the panel directory: " PTERO_PANEL
    PTERO_PANEL=$(ensure_path_format "$PTERO_PANEL")
    if [[ ! -d "$PTERO_PANEL" ]]; then
        print_msg "$RED" "[!] The panel directory does not exist. Please ensure that the panel directory is correct before running Blueprint."
        exit 1
    fi

    IS_MODIFIED=false
    if ! diff -q <(curl -s https://raw.githubusercontent.com/pterodactyl/panel/develop/routes/admin.php) "${PTERO_PANEL}routes/admin.php" &>/dev/null; then
        IS_MODIFIED=true
    fi
    if ! diff -q <(curl -s https://raw.githubusercontent.com/pterodactyl/panel/develop/resources/scripts/routers/routes.ts) "${PTERO_PANEL}resources/scripts/routers/routes.ts" &>/dev/null; then
        IS_MODIFIED=true
    fi

    if [[ $IS_MODIFIED == "true" ]]; then
        print_msg "$RED" "[!] Blueprint has detected that the panel has been modified. Please ensure that the panel is not modified before running Blueprint."
        exit 1
    fi

    print_msg "$GREEN" "Starting installation process..."

    # Start loading animation
    start_loading &
    LOADING_PID=$!

    # Installation steps
    print_msg "$GREEN" "Updating package lists..."
    apt-get update -y
    
    print_msg "$GREEN" "Installing necessary packages: ca-certificates, curl, gnupg..."
    apt-get install -y ca-certificates curl gnupg

    print_msg "$GREEN" "Adding Blueprint repository and installing..."
    # Assuming these are the steps required; adjust according to actual requirements
    curl -s https://example.com/blueprint_repo.gpg | apt-key add -
    echo "deb [trusted=yes] https://example.blueprint.com/ any main" | tee /etc/apt/sources.list.d/blueprint.list
    apt-get update -y
    apt-get install blueprint -y

    # Configuration steps (placeholder, replace with actual configuration commands)
    print_msg "$GREEN" "Configuring Blueprint..."
    # Example: blueprint configure --option=value

    # Stop loading animation
    stop_loading

    print_msg "$GREEN" "Blueprint installation completed successfully!"
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
