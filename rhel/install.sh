install_bp(){
echo "Enter the path to the panel directory. default : /var/www/pterodactyl/"
        read -r PTERO_PANEL
        PTERO_PANEL=${PTERO_PANEL:-/var/www/pterodactyl/} # Use default value if input is empty
        PTERO_PANEL=$(ensure_path_format "$PTERO_PANEL")

        # Check if the panel directory exists
        if [[ ! -d "$PTERO_PANEL" ]]; then
            echo -e "${RED}[!] The panel directory does not exist. Please ensure that the panel directory is correct before running Blueprint.${NC}"
            exit 1
        fi

        start_loading

        # Installing dependencies

    sudo yum install -y ca-certificates curl gnupg unzip zip &> /dev/null
    yum install wget -y &> /dev/null
     curl -sL https://rpm.nodesource.com/setup_20.x | sudo bash - &> /dev/null
    sudo yum update &> /dev/null
    yum install nodejs -y &> /dev/null
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
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/BlueprintFramework/main/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)
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
export -f install_bp
../main.sh
export -f start_loading
../main.sh
export -f stop_loading
../main.sh
