read -p "$(echo -e "${Y}Do you want to reinstall blueprint extensions? (${G}y${Y}/${R}n${NC}): \n${R}Do note that there can be breaking changes.${NC}")" reinstall_choice

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
                blueprint -install "$blueprint_file"
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
