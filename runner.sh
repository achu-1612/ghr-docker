#!/bin/bash

# GitHub Actions Self-Hosted Runner Manager
# This script manages Docker-based GitHub Actions runners with profile support

set -e

# Configuration
PROFILES_FILE=".profiles.json"
IMAGE_NAME="github-runner"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize variables
COMMAND=""
PROFILE=""
OWNER=""
REPO=""
RUNNER_NAME_PREFIX="docker-runner"
RUNNER_COUNT=1

# Parse command line arguments
COMMAND="$1"
shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --prefix)
            RUNNER_NAME_PREFIX="$2"
            shift 2
            ;;
        --count)
            RUNNER_COUNT="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to load profile
load_profile() {
    local profile_name="$1"
    
    if [ ! -f "$PROFILES_FILE" ]; then
        echo -e "${RED}Error: Profiles file not found${NC}"
        return 1
    fi
    
    if ! jq -e ".\"$profile_name\"" "$PROFILES_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Profile '$profile_name' not found${NC}"
        return 1
    fi
    
    OWNER=$(jq -r ".\"$profile_name\".OWNER" "$PROFILES_FILE")
    REPO=$(jq -r ".\"$profile_name\".REPO" "$PROFILES_FILE")
    RUNNER_NAME_PREFIX=$(jq -r ".\"$profile_name\".RUNNER_NAME_PREFIX" "$PROFILES_FILE")
    RUNNER_COUNT=$(jq -r ".\"$profile_name\".RUNNER_COUNT" "$PROFILES_FILE")
}

# Function to select profile interactively
select_profile() {
    if [ ! -f "$PROFILES_FILE" ] || [ "$(jq 'keys | length' "$PROFILES_FILE" 2>/dev/null)" = "0" ]; then
        echo -e "${RED}No profiles found. Create one first with: make profiles create${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Available Profiles:${NC}"
    echo ""
    jq -r 'keys | to_entries[] | "  \(.key + 1). \(.value)"' "$PROFILES_FILE"
    echo ""
    read -p "Select a profile (enter number or name): " selection
    
    if [ -z "$selection" ]; then
        echo -e "${RED}No profile selected${NC}"
        exit 1
    fi
    
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        PROFILE=$(jq -r "keys[$selection - 1] // empty" "$PROFILES_FILE")
    else
        PROFILE="$selection"
    fi
    
    if [ -z "$PROFILE" ] || ! jq -e ".\"$PROFILE\"" "$PROFILES_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Invalid selection${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Selected profile: $PROFILE${NC}"
    echo ""
}

# Function to validate configuration
validate_config() {
    if [ -z "$OWNER" ]; then
        echo -e "${RED}Error: OWNER is required${NC}"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        exit 1
    fi
}

# Helper function to load and display profile
load_and_display_profile() {
    if [ -n "$PROFILE" ]; then
        load_profile "$PROFILE"
    elif [ -z "$OWNER" ]; then
        select_profile
        load_profile "$PROFILE"
    fi
    
    if [ -n "$PROFILE" ]; then
        echo -e "${GREEN}Using profile: $PROFILE${NC}"
        echo "  OWNER=$OWNER"
        echo "  REPO=$REPO"
        echo "  RUNNER_NAME_PREFIX=$RUNNER_NAME_PREFIX"
        echo "  RUNNER_COUNT=$RUNNER_COUNT"
        echo ""
    fi
}

# Helper function to get container name
get_container_name() {
    local index="$1"
    if [ -n "$REPO" ]; then
        echo "${OWNER}_${REPO}_${RUNNER_NAME_PREFIX}-${index}"
    else
        echo "${OWNER}_${RUNNER_NAME_PREFIX}-${index}"
    fi
}

# Helper function to get API paths and runner URL
setup_github_config() {
    if [ -n "$REPO" ]; then
        RUNNER_URL="https://github.com/$OWNER/$REPO"
        API_PATH="repos/$OWNER/$REPO/actions/runners"
        echo "Type: Repository-level runners"
    else
        RUNNER_URL="https://github.com/$OWNER"
        API_PATH="orgs/$OWNER/actions/runners"
        echo "Type: Organization-level runners"
    fi
}

# Helper function to get registration token
get_registration_token() {
    echo "Getting registration token..." >&2
    local token=$(MSYS_NO_PATHCONV=1 gh api -X POST "${API_PATH}/registration-token" --jq .token 2>/dev/null)
    
    if [ -z "$token" ]; then
        echo -e "${RED}Error: Failed to get registration token. Make sure:${NC}" >&2
        echo "  1. GitHub CLI (gh) is installed and authenticated" >&2
        echo "  2. You have admin access to the repository/organization" >&2
        exit 1
    fi
    
    echo "$token"
}

# Function to get runner containers
get_containers() {
    docker ps -a --format "{{.Names}}" | grep -E "^[^_]+_[^_]+_.*$|^[^_]+_[^_]+$" 2>/dev/null || true
}

# Commands

cmd_help() {
    cat << EOF
GitHub Actions Self-Hosted Runner - Manager

Usage:
  ./runner.sh <command> [options]

Commands:
  build              - Build the Docker image
  run                - Run runners (interactive profile selection)
  restart            - Restart existing runner containers
  redeploy           - Remove and redeploy runners (full rebuild)
  stop               - Stop all runners
  logs               - Show logs for all runners
  status             - Show status of all runners
  deregister         - Deregister runners (interactive profile selection)
  remove             - Deregister and remove runners (interactive profile selection)
  clean              - Stop and remove all runner containers (without deregistering)
  
  profiles create    - Create a new profile
  profiles list      - List all saved profiles
  profiles show      - Show a specific profile
  profiles delete    - Delete a profile

Options:
  --profile <name>   - Profile name to use (skips interactive selection)
  --owner <name>     - GitHub username or organization name
  --repo <name>      - Repository name (optional, omit for organization-level)
  --prefix <name>    - Runner name prefix (default: docker-runner)
  --count <number>   - Number of runners to create (default: 1)

Examples:
  ./runner.sh run
  ./runner.sh run --profile myprofile
  ./runner.sh run --owner username --repo repo-name --count 3
EOF
}

cmd_profiles_create() {
    echo -e "${GREEN}Create New Profile${NC}"
    echo ""
    
    read -p "Profile name: " profile_name
    
    if [ -f "$PROFILES_FILE" ] && jq -e ".\"$profile_name\"" "$PROFILES_FILE" >/dev/null 2>&1; then
        read -p "$(echo -e ${YELLOW})Profile '$profile_name' already exists. Overwrite? (y/n): $(echo -e ${NC})" overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            echo -e "${YELLOW}Profile creation cancelled${NC}"
            exit 0
        fi
    fi
    
    read -p "Enter GitHub username or organization name: " owner
    read -p "Enter repository name (leave empty for organization-level): " repo
    read -p "Enter runner name prefix [docker-runner]: " prefix
    prefix=${prefix:-docker-runner}
    read -p "Enter number of runners [1]: " count
    count=${count:-1}
    
    if [ ! -f "$PROFILES_FILE" ]; then
        echo '{}' > "$PROFILES_FILE"
    fi
    
    jq ".\"$profile_name\" = {\"OWNER\": \"$owner\", \"REPO\": \"$repo\", \"RUNNER_NAME_PREFIX\": \"$prefix\", \"RUNNER_COUNT\": $count}" "$PROFILES_FILE" > "$PROFILES_FILE.tmp" && mv "$PROFILES_FILE.tmp" "$PROFILES_FILE"
    
    echo ""
    echo -e "${GREEN}✓ Profile '$profile_name' created successfully!${NC}"
    echo "  Use with: ./runner.sh run --profile $profile_name"
}

cmd_profiles_list() {
    echo -e "${GREEN}Saved Profiles:${NC}"
    echo ""
    
    if [ ! -f "$PROFILES_FILE" ] || [ "$(jq 'keys | length' "$PROFILES_FILE" 2>/dev/null)" = "0" ]; then
        echo -e "${YELLOW}No profiles found. Create one with './runner.sh profiles create'${NC}"
    else
        jq -r 'to_entries[] | "\u001b[1;33mProfile: \(.key)\u001b[0m\n  OWNER=\(.value.OWNER)\n  REPO=\(.value.REPO)\n  RUNNER_NAME_PREFIX=\(.value.RUNNER_NAME_PREFIX)\n  RUNNER_COUNT=\(.value.RUNNER_COUNT)\n"' "$PROFILES_FILE"
    fi
}

cmd_profiles_show() {
    if [ -z "$PROFILE" ]; then
        echo -e "${RED}Error: --profile parameter is required${NC}"
        exit 1
    fi
    
    if [ ! -f "$PROFILES_FILE" ] || ! jq -e ".\"$PROFILE\"" "$PROFILES_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Profile '$PROFILE' not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Profile: $PROFILE${NC}"
    jq -r ".\"$PROFILE\" | to_entries[] | \"  \(.key)=\(.value)\"" "$PROFILES_FILE"
}

cmd_profiles_delete() {
    if [ -z "$PROFILE" ]; then
        echo -e "${RED}Error: --profile parameter is required${NC}"
        exit 1
    fi
    
    if [ ! -f "$PROFILES_FILE" ] || ! jq -e ".\"$PROFILE\"" "$PROFILES_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Profile '$PROFILE' not found${NC}"
        exit 1
    fi
    
    read -p "Delete profile '$PROFILE'? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        jq "del(.\"$PROFILE\")" "$PROFILES_FILE" > "$PROFILES_FILE.tmp" && mv "$PROFILES_FILE.tmp" "$PROFILES_FILE"
        echo -e "${GREEN}✓ Profile '$PROFILE' deleted${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled${NC}"
    fi
}

cmd_build() {
    echo -e "${GREEN}Building Docker image...${NC}"
    docker build -t "$IMAGE_NAME" .
    echo -e "${GREEN}Build complete!${NC}"
}

cmd_run() {
    load_and_display_profile
    validate_config
    cmd_build
    
    echo -e "${GREEN}Starting $RUNNER_COUNT runner(s)...${NC}"
    setup_github_config
    RUNNER_TOKEN=$(get_registration_token)
    
    for i in $(seq 1 "$RUNNER_COUNT"); do
        RUNNER_NAME="$RUNNER_NAME_PREFIX-$i"
        CONTAINER_NAME=$(get_container_name "$i")
        
        echo "Starting runner: $RUNNER_NAME (container: $CONTAINER_NAME)"
        
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart unless-stopped \
            -e "RUNNER_URL=$RUNNER_URL" \
            -e "RUNNER_TOKEN=$RUNNER_TOKEN" \
            -e "RUNNER_NAME=$RUNNER_NAME" \
            "$IMAGE_NAME"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Runner $RUNNER_NAME started successfully${NC}"
        else
            echo -e "${RED}✗ Failed to start runner $RUNNER_NAME${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}All runners started!${NC}"
    echo "View logs with: ./runner.sh logs"
}

cmd_stop() {
    echo -e "${YELLOW}Stopping all runners...${NC}"
    
    CONTAINERS=$(get_containers)
    
    if [ -z "$CONTAINERS" ]; then
        echo -e "${YELLOW}No runner containers found${NC}"
    else
        for container in $CONTAINERS; do
            echo "Stopping $container..."
            docker stop "$container"
        done
        echo -e "${GREEN}All runners stopped${NC}"
    fi
}

cmd_logs() {
    echo -e "${GREEN}Recent logs from all runners:${NC}"
    echo ""
    
    CONTAINERS=$(get_containers)
    
    if [ -z "$CONTAINERS" ]; then
        echo -e "${YELLOW}No runner containers found${NC}"
    else
        for container in $CONTAINERS; do
            echo -e "${YELLOW}=== $container ===${NC}"
            docker logs --tail 20 "$container" 2>&1
            echo ""
        done
    fi
}

cmd_clean() {
    cmd_stop
    
    echo -e "${YELLOW}Removing all runner containers...${NC}"
    
    CONTAINERS=$(get_containers)
    
    if [ -z "$CONTAINERS" ]; then
        echo -e "${YELLOW}No runner containers found${NC}"
    else
        for container in $CONTAINERS; do
            echo "Removing $container..."
            docker rm "$container"
        done
        echo -e "${GREEN}All runners removed${NC}"
    fi
}

cmd_status() {
    echo -e "${GREEN}Runner Status:${NC}"
    echo ""
    
    CONTAINERS=$(docker ps -a --format "{{.Names}}|{{.Status}}|{{.CreatedAt}}" | grep -E "^[^_]+_[^_]+_.*|^[^_]+_[^_]+" 2>/dev/null || true)
    
    if [ -z "$CONTAINERS" ]; then
        echo -e "${YELLOW}No runner containers found${NC}"
    else
        printf "${YELLOW}%-20s %-20s %-25s %-15s %s${NC}\n" "OWNER" "REPO/ORG" "RUNNER NAME" "STATUS" "CREATED"
        printf "%-20s %-20s %-25s %-15s %s\n" "--------------------" "--------------------" "-------------------------" "---------------" "--------------------"
        
        echo "$CONTAINERS" | while IFS='|' read -r container status created; do
            CONTAINER_OWNER=$(echo "$container" | cut -d'_' -f1)
            CONTAINER_REPO=$(echo "$container" | cut -d'_' -f2)
            CONTAINER_RUNNER=$(echo "$container" | cut -d'_' -f3-)
            
            if [ -z "$CONTAINER_RUNNER" ]; then
                CONTAINER_RUNNER="$CONTAINER_REPO"
                CONTAINER_REPO="(org-level)"
            fi
            
            CREATED_SHORT=$(echo "$created" | cut -d' ' -f1-2)
            printf "%-20s %-20s %-25s %-15s %s\n" "$CONTAINER_OWNER" "$CONTAINER_REPO" "$CONTAINER_RUNNER" "$status" "$CREATED_SHORT"
        done
    fi
}

cmd_deregister() {
    load_and_display_profile
    validate_config
    
    echo -e "${YELLOW}Deregistering runners from GitHub...${NC}"
    setup_github_config
    
    for i in $(seq 1 "$RUNNER_COUNT"); do
        RUNNER_NAME="$RUNNER_NAME_PREFIX-$i"
        echo "Deregistering runner: $RUNNER_NAME"
        
        RUNNER_ID=$(gh api "$API_PATH" --jq ".runners[] | select(.name==\"$RUNNER_NAME\") | .id" 2>/dev/null)
        
        if [ -n "$RUNNER_ID" ]; then
            echo "  Found runner ID: $RUNNER_ID"
            if MSYS_NO_PATHCONV=1 gh api -X DELETE "$API_PATH/$RUNNER_ID" 2>/dev/null; then
                echo -e "  ${GREEN}✓ Successfully deregistered $RUNNER_NAME${NC}"
            else
                echo -e "  ${RED}✗ Failed to deregister $RUNNER_NAME${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Runner $RUNNER_NAME not found in GitHub${NC}"
        fi
    done
    
    echo -e "${GREEN}Deregistration complete${NC}"
}

cmd_restart() {
    load_and_display_profile
    
    echo -e "${YELLOW}Restarting runner containers...${NC}"
    
    for i in $(seq 1 "$RUNNER_COUNT"); do
        CONTAINER_NAME=$(get_container_name "$i")
        
        if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            echo "Restarting $CONTAINER_NAME..."
            docker restart "$CONTAINER_NAME"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Container restarted successfully${NC}"
            else
                echo -e "${RED}✗ Failed to restart container${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Container $CONTAINER_NAME not found${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}All containers restarted!${NC}"
}

cmd_redeploy() {
    load_and_display_profile
    validate_config
    
    echo -e "${YELLOW}Redeploying runners (remove + rebuild + run)...${NC}"
    echo ""
    
    # Stop and remove containers for this profile
    for i in $(seq 1 "$RUNNER_COUNT"); do
        CONTAINER_NAME=$(get_container_name "$i")
        
        if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            echo "Stopping $CONTAINER_NAME..."
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1
            echo "Removing $CONTAINER_NAME..."
            docker rm "$CONTAINER_NAME" >/dev/null 2>&1
        fi
    done
    
    echo ""
    echo -e "${GREEN}Containers stopped and removed. Starting fresh runners...${NC}"
    echo ""
    
    cmd_build
    
    setup_github_config
    RUNNER_TOKEN=$(get_registration_token)
    
    for i in $(seq 1 "$RUNNER_COUNT"); do
        RUNNER_NAME="$RUNNER_NAME_PREFIX-$i"
        CONTAINER_NAME=$(get_container_name "$i")
        
        echo "Starting runner: $RUNNER_NAME (container: $CONTAINER_NAME)"
        
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart unless-stopped \
            -e "RUNNER_URL=$RUNNER_URL" \
            -e "RUNNER_TOKEN=$RUNNER_TOKEN" \
            -e "RUNNER_NAME=$RUNNER_NAME" \
            "$IMAGE_NAME" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Runner $RUNNER_NAME deployed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to deploy runner $RUNNER_NAME${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}All runners redeployed!${NC}"
}

cmd_remove() {
    load_and_display_profile
    validate_config
    
    echo -e "${YELLOW}Removing runners (deregister + cleanup)...${NC}"
    echo ""
    read -p "This will deregister runners from GitHub and remove containers. Continue? (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        cmd_deregister
        echo ""
        cmd_clean
        echo ""
        echo -e "${GREEN}All runners removed and deregistered!${NC}"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
}

# Main command dispatcher
case "$COMMAND" in
    help|--help|-h)
        cmd_help
        ;;
    build)
        cmd_build
        ;;
    run)
        cmd_run
        ;;
    restart)
        cmd_restart
        ;;
    redeploy)
        cmd_redeploy
        ;;
    stop)
        cmd_stop
        ;;
    logs)
        cmd_logs
        ;;
    status)
        cmd_status
        ;;
    clean)
        cmd_clean
        ;;
    deregister)
        cmd_deregister
        ;;
    remove)
        cmd_remove
        ;;
    profiles)
        SUBCOMMAND="$1"
        shift || true
        case "$SUBCOMMAND" in
            create)
                cmd_profiles_create
                ;;
            list)
                cmd_profiles_list
                ;;
            show)
                cmd_profiles_show
                ;;
            delete)
                cmd_profiles_delete
                ;;
            *)
                echo -e "${RED}Unknown profiles command: $SUBCOMMAND${NC}"
                echo "Available: create, list, show, delete"
                exit 1
                ;;
        esac
        ;;
    "")
        echo -e "${RED}Error: No command specified${NC}"
        echo "Run './runner.sh help' for usage information"
        exit 1
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo "Run './runner.sh help' for usage information"
        exit 1
        ;;
esac
