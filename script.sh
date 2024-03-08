#!/bin/bash

# Check if the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

echo "Select an option:"
echo "1) Install Blueprint"
echo "2) Uninstall Blueprint"
read -p "Enter your choice (1 or 2): " choice

case "$choice" in
1)
echo "Starting installation process..."
    echo "Installing necessary packages: ca-certificates, curl, gnupg..."
    sudo apt-get install -y ca-certificates curl gnupg

    echo "Creating /etc/apt/keyrings directory..."
    sudo mkdir -p /etc/apt/keyrings

    echo "Adding NodeSource GPG key..."
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    echo "Adding NodeSource repository..."
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

    echo "Updating package lists..."
    sudo apt-get update

    echo "Installing Node.js..."
    sudo apt-get install -y nodejs

    echo "Installing Yarn globally..."
    sudo npm i -g yarn

    echo "Changing directory to /var/www/pterodactyl..."
    cd /var/www/pterodactyl || exit

    echo "Installing dependencies with Yarn..."
    yarn

    echo "Downloading the latest release of teamblueprint/main..."
    wget $(curl -s https://api.github.com/repos/teamblueprint/main/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4) -O latest_release.zip

    echo "Unzipping the latest release..."
    unzip -o latest_release.zip

    echo "Making blueprint.sh executable..."
    chmod +x blueprint.sh

    echo "Executing blueprint.sh..."
    ./blueprint.sh
    ;;
2)
    # Uninstallation process
    echo "WARNING!: The following uninstall will remove blueprint and most* of its components."
    echo "This will also delete your app/, public/, resources/, and ./blueprint folders."
    read -p "Are you sure you want to continue with the uninstall (y/n): " choice

    case "$choice" in
      y|Y) 
        echo "Continuing with the uninstallation..."
        ;;
      n|N) 
        echo "Exiting the script."
        exit
        ;;
      *) 
        echo "Invalid choice. Please enter 'y' for yes or 'n' for no."
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

    read -p "Current directory: $directory. Press Enter to confirm, or enter a new directory: " new_directory

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

    read -p "Do you want to update your database schema for the newest version of Pterodactyl? (y/n): " choice

    case "$choice" in
      y|Y) 
        echo "Updating database schema..."
        php artisan migrate --seed --force
        ;;
      n|N) 
        echo "Skipping database schema update."
        ;;
      *) 
        echo "Invalid choice."
        exit 1
        ;;
    esac

    echo "Finishing up..."
    chown -R www-data:www-data $directory
    php artisan queue:restart
    php artisan up
    chown -R www-data:www-data $directory
    echo "If you want to update your dependencies also, run:"
    echo "composer install --no-dev --optimize-autoloader"
    echo "As composer's recommendation, do NOT run it as root."
    echo "See https://getcomposer.org/root for details."
    cd $currentLoc
    echo "Uninstallation and update process completed!"
    ;;
*)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac
