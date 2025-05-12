#!/bin/bash

# ===== Color Definitions =====
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
YELLOW_COLOR='\033[0;33m'
BLUE_COLOR='\033[0;34m'
PURPLE_COLOR='\033[0;35m'
NO_COLOR='\033[0m'

# ===== Utility Functions =====
list_items_with_numbers() {
    local command_to_execute=$1
    local text_color=$2
    eval "$command_to_execute" | awk -v color="$text_color" '{print color NR ". " $0 "\033[0m"}'
}

get_item_by_number() {
    local command_to_execute=$1
    local item_number=$2
    eval "$command_to_execute" | sed -n "${item_number}p" | awk '{print $1}'
}
# Display lists
echo -e "${BLUE}Listing containers:${NC}"
list_items_with_numbers "docker ps -a --format \"{{.ID}}\t{{.Names}}\t{{.Status}}\"" "$BLUE_COLOR"

echo -e "\n${YELLOW}Listing volumes:${NC}"
list_items_with_numbers "docker volume ls --format \"{{.Name}}\"" "$YELLOW_COLOR"

echo -e "\n${RED}Listing networks:${NC}"
list_items_with_numbers "docker network ls --format \"{{.ID}}\t{{.Name}}\t{{.Driver}}\"" "$RED_COLOR"

echo -e "\n${PURPLE}Listing images:${NC}"
list_items_with_numbers "docker images --format \"{{.ID}}\t{{.Repository}}\t{{.Tag}}\"" "$PURPLE_COLOR"

# ===== Resource Listing Functions =====
update_resource_listings() {
    echo -e "${YELLOW_COLOR}Updating listings...${NO_COLOR}"
    sleep 3

    echo -e "\n${BLUE_COLOR}Listing containers:${NO_COLOR}"
    list_items_with_numbers "docker ps -a --format \"{{.ID}}\t{{.Names}}\t{{.Status}}\"" "$BLUE_COLOR"

    echo -e "\n${YELLOW_COLOR}Listing volumes:${NO_COLOR}"
    list_items_with_numbers "docker volume ls --format \"{{.Name}}\"" "$YELLOW_COLOR"

    echo -e "\n${RED_COLOR}Listing networks:${NO_COLOR}"
    list_items_with_numbers "docker network ls --format \"{{.ID}}\t{{.Name}}\t{{.Driver}}\"" "$RED_COLOR"

    echo -e "\n${PURPLE_COLOR}Listing images:${NO_COLOR}"
    list_items_with_numbers "docker images --format \"{{.ID}}\t{{.Repository}}\t{{.Tag}}\"" "$PURPLE_COLOR"
}

# ===== Resource Deletion Functions =====
delete_containers() {
    echo "Enter the numbers of containers to delete (comma-separated), or type \"all\":"
    read -r container_numbers
    if [ "$container_numbers" = "all" ]; then
        docker rm "$(docker ps -aq)"
    else
        IFS=',' read -ra selected_numbers <<<"$container_numbers"
        for number in "${selected_numbers[@]}"; do
            container=$(echo "$container_list" | sed -n "${number}p" | awk '{print $1}')
            [ -n "$container" ] && docker rm "$container"
        done
    fi
    echo "Containers deletion completed."
    update_resource_listings
}

delete_volumes() {
    echo "Enter the numbers of volumes to delete (comma-separated), or type \"all\":"
    read -r volume_numbers
    if [ "$volume_numbers" = "all" ]; then
        docker volume rm "$(docker volume ls -q)"
    else
        IFS=',' read -ra selected_numbers <<<"$volume_numbers"
        for number in "${selected_numbers[@]}"; do
            volume=$(echo "$volume_list" | sed -n "${number}p")
            [ -n "$volume" ] && docker volume rm "$volume"
        done
    fi
    echo "Volumes deletion completed."
    update_resource_listings
}

delete_networks() {
    echo "Enter the numbers of networks to delete (comma-separated), or type \"all\":"
    read -r network_numbers
    if [ "$network_numbers" = "all" ]; then
        docker network rm "$(docker network ls -q --filter type=custom)"
    else
        IFS=',' read -ra selected_numbers <<<"$network_numbers"
        for number in "${selected_numbers[@]}"; do
            network=$(echo "$network_list" | sed -n "${number}p" | awk '{print $1}')
            if [ -n "$network" ]; then
                if ! docker network inspect "$network" | grep -q '"Scope": "local"'; then
                    docker network rm "$network"
                else
                    echo "Skipping pre-defined network: $network"
                fi
            fi
        done
    fi
    echo "Networks deletion completed."
    update_resource_listings
}

delete_images() {
    echo "Enter the numbers of images to delete (comma-separated), or type \"all\":"
    read -r image_numbers
    if [ "$image_numbers" = "all" ]; then
        docker rmi "$(docker images -q)"
    else
        IFS=',' read -ra selected_numbers <<<"$image_numbers"
        for number in "${selected_numbers[@]}"; do
            image=$(echo "$image_list" | sed -n "${number}p" | awk '{print $1}')
            [ -n "$image" ] && docker rmi "$image"
        done
    fi
    echo "Images deletion completed."
    update_resource_listings
}

# ===== Main Script =====
# Store resource lists in variables
container_list=$(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Status}}")
volume_list=$(docker volume ls --format "{{.Name}}")
network_list=$(docker network ls --format "{{.ID}}\t{{.Name}}\t{{.Driver}}")
image_list=$(docker images --format "{{.ID}}\t{{.Repository}}\t{{.Tag}}")

# Initial resource listing
# update_resource_listings

# Main loop
while true; do
    echo -e "${GREEN_COLOR}Enter what you want to delete:${NO_COLOR}\n${BLUE_COLOR}1. containers${NO_COLOR}\n${YELLOW_COLOR}2. volumes${NO_COLOR}\n${RED_COLOR}3. networks${NO_COLOR}\n${PURPLE_COLOR}4. images${NO_COLOR}\n${GREEN_COLOR}or type \"5. skip\" to exit:${NO_COLOR}"
    read -r user_choice

    case ${user_choice%s} in
    container | 1)
        delete_containers
        ;;
    volume | 2)
        delete_volumes
        ;;
    network | 3)
        delete_networks
        ;;
    image | 4)
        delete_images
        ;;
    skip | 5)
        echo "Exiting without deleting anything."
        echo "Exiting Docker Cleanup. Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${RED_COLOR}Invalid choice. Please try again.${NO_COLOR}"
        continue
        ;;
    esac
done
