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
# Install Function 
install_bp(){
echo "Enter the path to the panel directory. default : /var/www/pterodactyl/"
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
# Function to start updating loading animation
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

# Function to stop updating loading animation
stop_uloading() {
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
echo -e "2) Uninstall Blueprint"
echo -e "3) Update Pterodactyl & Blueprint"
echo -e "4) Install Pterodactyl & Blueprint${NC}"
read -p "$(echo -e "${YELLOW}Enter your choice (1,2,3 or 4): ${NC}")" choice

case "$choice" in
    1)
         install_bp
        ;;
        # Uninstallation Process
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
                php artisan migrate -q --seed --force
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
        3)
        echo -e "WARNING: ${RED}updating will make pterodactyl unavailable, please note that you WILL need to reinstall your blueprint extensions."
        read -p "$(echo -e "${YELLOW} Are you sure you want to continue with the update? (${GREEN}y${YELLOW}/${RED}n${NC}): ")" choice
        case "$choice" in
            y|Y)
            # Putting Pterodactyl into maintenance mode
            echo -e "${GREEN}Pterodactyl is now in maintenance mode.${NC}"
                cd /var/www/pterodactyl
                php artisan down
                # Downloading the ptero update.
                echo -e "${GREEN}Downloading the latest version of Pterodactyl...${NC}"
                curl -L -s https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xz
                # Setting up permissions
                chmod -R 755 storage/* bootstrap/cache
                #Updating Dependencies
                start_uloading
                composer install --no-dev --optimize-autoloader --quiet
                stop_uloading
                # Clearing views and configs
                echo -e "${GREEN}Clearing views and configs...${NC}"
                php artisan view:clear
                php artisan config:clear
                php artisan migrate -q --seed --force
                # Setting up Web Server Perms
                echo -e "${GREEN}Setting up Web Server Permissions...${NC}"
                chown -R www-data:www-data /var/www/pterodactyl/*
                #Restarting Workers
                echo -e "${GREEN}Restarting Workers...${NC}"
                php artisan queue:restart
                #Exiting Maintenance Mode
                echo -e "${GREEN}Pterodactyl is now back online.${NC}"
                php artisan up
                #Reinstallating BP
                install_bp
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
              ;;
              4)
              # Add "add-apt-repository" command
              start_loading
             sudo apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg -qq

              # Add additional repositories for PHP, Redis, and MariaDB
              LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
stop_loading
              # Add Redis official APT repository
              curl -s -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
              echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

              # MariaDB repo setup script can be skipped on Ubuntu 22.04
              start_loading
             sudo curl -sS -s https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

              # Update repositories list
              sudo apt update -qq

              # Install Dependencies
              apt -y install php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server -qq
              stop_loading
# Installing Composer
echo -e "${GREEN}Installing Composer...${NC}"
sudo curl -s -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
# Creating the directories
echo -e "${GREEN}Creating the directories...${NC}"
sudo mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
# Downloading Ptero 
echo -e "${GREEN}Downloading Pterodactyl...${NC}"
sudo curl -s -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
sudo tar -xzf panel.tar.gz
sudo chmod -R 755 storage/* bootstrap/cache/
echo "Enter a unique password for the MySQL 'pterodactyl' user:"
read -r pterodactyl_password

# Connect to MySQL, create the pterodactyl user, create the panel database, and grant privileges
echo -e "${GREEN}Connecting to MySQL...${NC}"
sudo mysql -u root -p <<MYSQL_SCRIPT
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$pterodactyl_password';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
exit
MYSQL_SCRIPT

echo -e "${GREEN}MySQL user 'pterodactyl' and database 'panel' have been created.${NC}"
#Copying env
echo -e "${GREEN}Copying env file & setup composer...${NC}"
sudo cp .env.example .env
sudo composer install -q --no-dev --optimize-autoloader

# Only run the command below if you are installing this Panel for
# the first time and do not have any Pterodactyl Panel data in the database.
echo -e "${GREEN}Creating the initial Pterodactyl Panel data...${NC}"
sudo php artisan key:generate --force
echo -e "WARNING: ${RED}Back up your encryption key (APP_KEY in the .env file). It is used as an encryption key for all data that needs to be stored securely (e.g. api keys). Store it somewhere safe - not just on your server. If you lose it all encrypted data is irrecoverable -- even if you have database backups.${NC}"
# Environment Config
sudo php artisan p:environment:setup
sudo php artisan p:environment:database
echo -e "${GREEN}Do you wish to add smtp to pterodactyl?${NC}"
read -p "$(echo -e "${YELLOW}Enter your choice (y/n): ${NC}")" choice
case "$choice" in
y)
echo -e "${GREEN}Adding smtp to pterodactyl...${NC}"
sudo php artisan p:environment:mail
#DB MIGRATE
echo -e "${GREEN}Migrating database...${NC}"
sudo php artisan migrate -q --seed --force
#First User
echo -e "${GREEN}Creating the first user...${NC}"
sudo php artisan p:user:make
echo -e "${GREEN}Setting up web server permissions and setting up crontab${NC}"
sudo chown -R www-data:www-data /var/www/pterodactyl/*
NEW_CRON_JOB="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v -F "$NEW_CRON_JOB"; echo "$NEW_CRON_JOB") | crontab -
sudo cat <<EOT >> /etc/systemd/system/pteroq.service
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOT
sudo systemctl enable --now redis-server
sudo systemctl enable --now pteroq.service
echo -e "${GREEN}Pterodactyl is now installed!${NC}"
install_bp
echo -e "${GREEN}Pterodactyl and Blueprint are now installed!${NC}"
;;
n)
echo -e "${GREEN}Skipping smtp setup...${NC}"

echo -e "${GREEN}Migrating database...${NC}"
sudo php artisan migrate -q --seed --force
#First User
echo -e "${GREEN}Creating the first user...${NC}"
sudo php artisan p:user:make
echo -e "${GREEN}Setting up web server permissions and setting up crontab${NC}"
sudo chown -R www-data:www-data /var/www/pterodactyl/*
NEW_CRON_JOB="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v -F "$NEW_CRON_JOB"; echo "$NEW_CRON_JOB") | crontab -
sudo cat <<EOT >> /etc/systemd/system/pteroq.service
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOT
sudo systemctl enable --now redis-server
sudo systemctl enable --now pteroq.service
echo -e "${GREEN}Pterodactyl is now installed!${NC}"
install_bp
echo -e "${GREEN}Pterodactyl and Blueprint are now installed!${NC}"
;;
*)
echo -e "${YELLOW}Invalid choice. Exiting.${NC}"
exit 1
;;
esac
;;
    *)
        echo "${YELLOW}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac
