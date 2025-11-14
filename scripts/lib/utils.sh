#!/bin/bash

# Utility functions for Arcane Template Setup Scripts
# Provides logging, prompts, confirmations, and helper functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

log_instruction() {
    echo -e "${MAGENTA}➜${NC} $1"
}

# Prompt for input with default value
prompt_input() {
    local prompt_text="$1"
    local default_value="$2"
    local result_var="$3"
    local user_input

    if [ -n "$default_value" ]; then
        read -p "$(echo -e ${CYAN}❯${NC}) $prompt_text [$default_value]: " user_input
        user_input="${user_input:-$default_value}"
    else
        read -p "$(echo -e ${CYAN}❯${NC}) $prompt_text: " user_input
    fi

    eval "$result_var='$user_input'"
}

# Prompt with validation
prompt_with_validation() {
    local prompt_text="$1"
    local validation_func="$2"
    local result_var="$3"
    local default_value="$4"
    local user_input
    local is_valid=false

    while [ "$is_valid" = false ]; do
        if [ -n "$default_value" ]; then
            read -p "$(echo -e ${CYAN}❯${NC}) $prompt_text [$default_value]: " user_input
            user_input="${user_input:-$default_value}"
        else
            read -p "$(echo -e ${CYAN}❯${NC}) $prompt_text: " user_input
        fi

        if $validation_func "$user_input"; then
            is_valid=true
        fi
    done

    eval "$result_var='$user_input'"
}

# Confirmation prompt
confirm() {
    local prompt_text="$1"
    local response

    while true; do
        read -p "$(echo -e ${GREEN}?${NC}) $prompt_text [Y/n]: " response
        response="${response:-Y}"
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Press enter to continue
press_enter() {
    local message="${1:-Press Enter to continue}"
    read -p "$(echo -e ${CYAN}⏎${NC}) $message..."
}

# Validation functions
validate_not_empty() {
    local value="$1"
    if [ -z "$value" ]; then
        log_error "Value cannot be empty"
        return 1
    fi
    return 0
}

validate_no_spaces() {
    local value="$1"
    if [[ "$value" =~ \  ]]; then
        log_error "Value cannot contain spaces. Use underscores instead."
        return 1
    fi
    return 0
}

validate_lowercase() {
    local value="$1"
    if [[ "$value" =~ [A-Z] ]]; then
        log_error "Value must be lowercase"
        return 1
    fi
    return 0
}

validate_no_special_chars() {
    local value="$1"
    if [[ "$value" =~ [^a-zA-Z0-9_] ]]; then
        log_error "Value can only contain letters, numbers, and underscores"
        return 1
    fi
    return 0
}

validate_app_name() {
    local value="$1"
    validate_not_empty "$value" || return 1
    validate_no_spaces "$value" || return 1
    validate_lowercase "$value" || return 1
    validate_no_special_chars "$value" || return 1
    return 0
}

validate_firebase_project_id() {
    local value="$1"
    validate_not_empty "$value" || return 1
    if [[ ! "$value" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Firebase Project ID can only contain lowercase letters, numbers, and hyphens"
        return 1
    fi
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Run command with error handling
run_command() {
    local description="$1"
    shift

    log_info "Running: $description"

    if "$@"; then
        log_success "Completed: $description"
        return 0
    else
        log_error "Failed: $description"
        return 1
    fi
}

# Run command with retry logic
# Usage: retry_command "description" command args...
retry_command() {
    local description="$1"
    shift

    local attempt=1
    local max_auto_retries=2

    while true; do
        if [ $attempt -eq 1 ]; then
            log_info "Running: $description"
        else
            log_info "Retry attempt $attempt: $description"
        fi

        # Run the command
        if "$@"; then
            log_success "Completed: $description"
            return 0
        fi

        # Command failed
        log_error "Failed: $description"

        # Auto-retry once
        if [ $attempt -lt $max_auto_retries ]; then
            log_warning "Retrying automatically..."
            echo ""
            attempt=$((attempt + 1))
            sleep 1
            continue
        fi

        # After auto-retry fails, ask user
        echo ""
        log_warning "Command has failed $attempt times"
        echo ""

        local choice
        while true; do
            read -p "$(echo -e ${YELLOW}?${NC}) Do you want to (r)etry, (s)kip, or (a)bort? [r/s/a]: " choice
            case "$choice" in
                [Rr]* )
                    attempt=$((attempt + 1))
                    echo ""
                    break
                    ;;
                [Ss]* )
                    log_warning "Skipping: $description"
                    return 1
                    ;;
                [Aa]* )
                    log_error "Aborting setup"
                    exit 1
                    ;;
                * )
                    echo "Please answer (r)etry, (s)kip, or (a)bort"
                    ;;
            esac
        done
    done
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir_path="$1"

    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        log_success "Created directory: $dir_path"
    fi
}

# Check if file exists
file_exists() {
    [ -f "$1" ]
}

# Convert snake_case to PascalCase
snake_to_pascal() {
    local input="$1"
    # Split by underscore and capitalize first letter of each word
    echo "$input" | awk -F_ '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' OFS=''
}

# Save configuration to file
save_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"

    # Create config directory if it doesn't exist
    ensure_directory "$(dirname "$config_file")"

    # Update or add key-value pair
    if [ -f "$config_file" ]; then
        # Check if key exists
        if grep -q "^${key}=" "$config_file"; then
            # Update existing key
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^${key}=.*|${key}=${value}|" "$config_file"
            else
                sed -i "s|^${key}=.*|${key}=${value}|" "$config_file"
            fi
        else
            # Add new key
            echo "${key}=${value}" >> "$config_file"
        fi
    else
        # Create new config file
        echo "${key}=${value}" > "$config_file"
    fi
}

# Load configuration from file
load_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        source "$config_file"
        log_success "Loaded configuration from $config_file"
    else
        log_warning "Configuration file not found: $config_file"
        return 1
    fi
}

# Export configuration variables
export_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        set -a
        source "$config_file"
        set +a
    fi
}

# Show progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Execute command with spinner
execute_with_spinner() {
    local description="$1"
    shift

    log_info "$description"

    # Execute command in background
    "$@" > /dev/null 2>&1 &
    local pid=$!

    # Show spinner
    spinner $pid

    # Wait for command to complete
    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_success "Completed: $description"
        return 0
    else
        log_error "Failed: $description"
        return 1
    fi
}

# Print section header
print_header() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                           ║${NC}"
    echo -e "${MAGENTA}║  $(printf '%-55s' "$1")  ║${NC}"
    echo -e "${MAGENTA}║                                                           ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print welcome banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                             ║${NC}"
    echo -e "${CYAN}║           ${MAGENTA}✨ Arcane Template Setup Wizard ✨${CYAN}              ║${NC}"
    echo -e "${CYAN}║                                                             ║${NC}"
    echo -e "${CYAN}║  ${NC}Create a complete Flutter app with Arcane UI framework  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${NC}including client, models, and server projects           ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                             ║${NC}"
    echo -e "${CYAN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Cleanup function for script interruption
cleanup() {
    echo ""
    log_warning "Setup interrupted by user"
    log_info "Partial setup may remain. You can:"
    log_info "  1. Run the script again to continue"
    log_info "  2. Manually clean up created directories"
    exit 1
}

# Set trap for cleanup
trap cleanup INT TERM
