#!/bin/bash

# Arcane Template Setup Wizard
# Main orchestration script for creating a complete 3-project Flutter application

set -e  # Exit on error

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library scripts
source "$SCRIPT_DIR/scripts/lib/utils.sh"
source "$SCRIPT_DIR/scripts/lib/check_tools.sh"
source "$SCRIPT_DIR/scripts/lib/create_projects.sh"
source "$SCRIPT_DIR/scripts/lib/copy_templates.sh"
source "$SCRIPT_DIR/scripts/lib/add_dependencies.sh"
source "$SCRIPT_DIR/scripts/lib/setup_firebase.sh"
source "$SCRIPT_DIR/scripts/lib/generate_configs.sh"
source "$SCRIPT_DIR/scripts/lib/generate_assets.sh"
source "$SCRIPT_DIR/scripts/lib/setup_server.sh"
source "$SCRIPT_DIR/scripts/lib/deploy_firebase.sh"

# Configuration file
CONFIG_FILE="config/setup_config.env"

# Global flags for non-interactive mode
FLAG_NON_INTERACTIVE=false
FLAG_SKIP_CONFIRM=false
FLAG_SKIP_CLI_CHECK=false
FLAG_WORK_DIR=""
FLAG_APP_NAME=""
FLAG_ORG_DOMAIN=""
FLAG_BASE_CLASS_NAME=""
FLAG_TEMPLATE=""
FLAG_WITH_MODELS=""
FLAG_WITH_SERVER=""
FLAG_WITH_FIREBASE=""
FLAG_FIREBASE_PROJECT_ID=""
FLAG_WITH_CLOUD_RUN=""
FLAG_SERVICE_ACCOUNT_KEY=""
FLAG_SKIP_DEPLOY=""

# Parse command-line flags
parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --rebuild|-r)
                # This is handled in main() for backward compatibility
                shift
                ;;
            --non-interactive|-n)
                FLAG_NON_INTERACTIVE=true
                shift
                ;;
            --skip-confirm)
                FLAG_SKIP_CONFIRM=true
                shift
                ;;
            --skip-cli-check)
                FLAG_SKIP_CLI_CHECK=true
                shift
                ;;
            --work-dir|--output-dir)
                FLAG_WORK_DIR="$2"
                shift 2
                ;;
            --app-name|--name)
                FLAG_APP_NAME="$2"
                shift 2
                ;;
            --org|--organization)
                FLAG_ORG_DOMAIN="$2"
                shift 2
                ;;
            --class-name|--base-class)
                FLAG_BASE_CLASS_NAME="$2"
                shift 2
                ;;
            --template)
                FLAG_TEMPLATE="$2"
                shift 2
                ;;
            --with-models|--models)
                FLAG_WITH_MODELS="yes"
                shift
                ;;
            --with-server|--server)
                FLAG_WITH_SERVER="yes"
                shift
                ;;
            --with-firebase|--firebase)
                FLAG_WITH_FIREBASE="yes"
                shift
                ;;
            --firebase-project-id|--firebase-id)
                FLAG_FIREBASE_PROJECT_ID="$2"
                shift 2
                ;;
            --with-cloud-run|--cloud-run)
                FLAG_WITH_CLOUD_RUN="yes"
                shift
                ;;
            --service-account-key|--key-file)
                FLAG_SERVICE_ACCOUNT_KEY="$2"
                shift 2
                ;;
            --skip-deploy)
                FLAG_SKIP_DEPLOY="yes"
                shift
                ;;
            *)
                log_error "Unknown flag: $1"
                log_info "Run './setup.sh --help' for usage information"
                exit 1
                ;;
        esac
    done
}

# Validate all required flags for non-interactive mode
validate_flags() {
    if [ "$FLAG_NON_INTERACTIVE" != true ]; then
        return 0
    fi

    local missing_flags=()

    if [ -z "$FLAG_APP_NAME" ]; then
        missing_flags+=("--app-name")
    fi

    if [ -z "$FLAG_ORG_DOMAIN" ]; then
        missing_flags+=("--org")
    fi

    if [ -z "$FLAG_TEMPLATE" ]; then
        missing_flags+=("--template")
    fi

    if [ "$FLAG_WITH_FIREBASE" = "yes" ] && [ -z "$FLAG_FIREBASE_PROJECT_ID" ]; then
        missing_flags+=("--firebase-project-id (required when --with-firebase is set)")
    fi

    if [ ${#missing_flags[@]} -gt 0 ]; then
        log_error "Non-interactive mode requires the following flags:"
        for flag in "${missing_flags[@]}"; do
            log_error "  $flag"
        done
        echo ""
        log_info "Run './setup.sh --help' for usage information"
        exit 1
    fi

    # Validate flag values
    if ! validate_app_name "$FLAG_APP_NAME"; then
        log_error "Invalid app name: $FLAG_APP_NAME"
        exit 1
    fi

    if ! validate_not_empty "$FLAG_ORG_DOMAIN"; then
        log_error "Invalid organization domain: $FLAG_ORG_DOMAIN"
        exit 1
    fi

    case "$FLAG_TEMPLATE" in
        1|arcane_template|2|arcane_beamer|3|arcane_dock)
            # Valid template
            ;;
        *)
            log_error "Invalid template: $FLAG_TEMPLATE"
            log_error "Must be one of: 1, arcane_template, 2, arcane_beamer, 3, arcane_dock"
            exit 1
            ;;
    esac

    if [ "$FLAG_WITH_FIREBASE" = "yes" ] && ! validate_firebase_project_id "$FLAG_FIREBASE_PROJECT_ID"; then
        log_error "Invalid Firebase project ID: $FLAG_FIREBASE_PROJECT_ID"
        exit 1
    fi

    log_success "All flags validated successfully"
}

# Apply flags to configuration variables
apply_flags() {
    if [ -n "$FLAG_APP_NAME" ]; then
        APP_NAME="$FLAG_APP_NAME"
    fi

    if [ -n "$FLAG_ORG_DOMAIN" ]; then
        ORG_DOMAIN="$FLAG_ORG_DOMAIN"
    fi

    if [ -n "$FLAG_BASE_CLASS_NAME" ]; then
        BASE_CLASS_NAME="$FLAG_BASE_CLASS_NAME"
    fi

    if [ -n "$FLAG_TEMPLATE" ]; then
        case "$FLAG_TEMPLATE" in
            1|arcane_template)
                TEMPLATE_DIR="$SCRIPT_DIR/arcane_template"
                TEMPLATE_NAME="arcane_template"
                PLATFORMS="android,ios,web,linux,windows,macos"
                ;;
            2|arcane_beamer)
                TEMPLATE_DIR="$SCRIPT_DIR/arcane_beamer"
                TEMPLATE_NAME="arcane_beamer"
                PLATFORMS="android,ios,web,linux,windows,macos"
                ;;
            3|arcane_dock)
                TEMPLATE_DIR="$SCRIPT_DIR/arcane_dock"
                TEMPLATE_NAME="arcane_dock"
                PLATFORMS="linux,windows,macos"
                ;;
        esac
    fi

    if [ -n "$FLAG_WITH_MODELS" ]; then
        CREATE_MODELS="$FLAG_WITH_MODELS"
    fi

    if [ -n "$FLAG_WITH_SERVER" ]; then
        CREATE_SERVER="$FLAG_WITH_SERVER"
    fi

    if [ -n "$FLAG_WITH_FIREBASE" ]; then
        USE_FIREBASE="$FLAG_WITH_FIREBASE"
    fi

    if [ -n "$FLAG_FIREBASE_PROJECT_ID" ]; then
        FIREBASE_PROJECT_ID="$FLAG_FIREBASE_PROJECT_ID"
    fi

    if [ -n "$FLAG_WITH_CLOUD_RUN" ]; then
        SETUP_CLOUD_RUN="$FLAG_WITH_CLOUD_RUN"
    fi

    # Set defaults for optional components if not specified
    CREATE_MODELS="${CREATE_MODELS:-no}"
    CREATE_SERVER="${CREATE_SERVER:-no}"
    USE_FIREBASE="${USE_FIREBASE:-no}"
    SETUP_CLOUD_RUN="${SETUP_CLOUD_RUN:-no}"

    # Auto-derive base class name if not provided
    if [ -z "$BASE_CLASS_NAME" ] && [ -n "$APP_NAME" ]; then
        BASE_CLASS_NAME=$(snake_to_pascal "$APP_NAME")
    fi
}

# Main setup function

load_existing_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi

    # Source the config file to load variables
    source "$CONFIG_FILE"

    # Validate required variables are set
    if [ -z "$APP_NAME" ] || [ -z "$ORG_DOMAIN" ] || [ -z "$TEMPLATE_NAME" ]; then
        log_error "Invalid configuration file - missing required variables"
        return 1
    fi

    # Set TEMPLATE_DIR based on TEMPLATE_NAME
    TEMPLATE_DIR="$SCRIPT_DIR/$TEMPLATE_NAME"

    # Set defaults for optional variables if not present
    CREATE_MODELS="${CREATE_MODELS:-no}"
    CREATE_SERVER="${CREATE_SERVER:-no}"
    USE_FIREBASE="${USE_FIREBASE:-no}"
    SETUP_CLOUD_RUN="${SETUP_CLOUD_RUN:-no}"
    FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}"
    BASE_CLASS_NAME="${BASE_CLASS_NAME:-$(snake_to_pascal "$APP_NAME")}"
    PLATFORMS="${PLATFORMS:-android,ios,web,linux,windows,macos}"

    log_success "Configuration loaded successfully"
    return 0
}

select_working_directory() {
    # If work directory was provided via flag, use it
    if [ -n "$FLAG_WORK_DIR" ]; then
        local target_dir="${FLAG_WORK_DIR/#\~/$HOME}"

        # Check if directory exists
        if [ ! -d "$target_dir" ]; then
            if [ "$FLAG_NON_INTERACTIVE" = true ]; then
                log_error "Directory does not exist: $target_dir"
                exit 1
            else
                log_warning "Directory does not exist: $target_dir"
                if confirm "Do you want to create it?"; then
                    if ! mkdir -p "$target_dir" 2>/dev/null; then
                        log_error "Failed to create directory: $target_dir"
                        exit 1
                    fi
                    log_success "Created directory: $target_dir"
                else
                    log_error "Cannot continue without valid directory"
                    exit 1
                fi
            fi
        fi

        # Check write permissions
        if [ ! -w "$target_dir" ]; then
            log_error "No write permission for directory: $target_dir"
            exit 1
        fi

        # Change to the directory
        if ! cd "$target_dir" 2>/dev/null; then
            log_error "Failed to change to directory: $target_dir"
            exit 1
        fi

        log_success "Using working directory: $(pwd)"
        return 0
    fi

    # Interactive mode
    log_info "Current directory: $(pwd)"
    log_instruction "Projects will be created as subdirectories in this location."
    echo ""

    if confirm "Do you want to use a different directory?"; then
        echo ""
        local target_dir
        local valid_dir=false

        while [ "$valid_dir" = false ]; do
            prompt_input "Enter directory path (~ for home directory)" "" target_dir

            # Expand ~ to home directory
            target_dir="${target_dir/#\~/$HOME}"

            # Check if directory exists
            if [ -d "$target_dir" ]; then
                log_success "Directory exists: $target_dir"
                valid_dir=true
            else
                log_warning "Directory does not exist: $target_dir"
                if confirm "Do you want to create it?"; then
                    if mkdir -p "$target_dir" 2>/dev/null; then
                        log_success "Created directory: $target_dir"
                        valid_dir=true
                    else
                        log_error "Failed to create directory. Please check permissions and try again."
                        continue
                    fi
                else
                    log_info "Please enter a different directory path"
                    continue
                fi
            fi

            # Check write permissions
            if [ ! -w "$target_dir" ]; then
                log_error "No write permission for directory: $target_dir"
                log_info "Please enter a different directory path"
                valid_dir=false
                continue
            fi

            # Change to the directory
            if cd "$target_dir" 2>/dev/null; then
                log_success "Changed working directory to: $(pwd)"
                echo ""
            else
                log_error "Failed to change to directory: $target_dir"
                valid_dir=false
            fi
        done
    fi
}

show_help() {
    cat << EOF
Arcane Template Setup Wizard

Create a complete Flutter application with Arcane UI framework, including client,
models package, and server projects.

USAGE:
    ./setup.sh [OPTIONS]

MODES:
    Interactive Mode (default):  Prompts for all configuration options
    Non-Interactive Mode:        Requires all mandatory flags, no prompts

CONFIGURATION FLAGS:
    --app-name NAME              App name (lowercase_with_underscores)
                                 Example: my_awesome_app

    --org DOMAIN                 Organization domain (reverse domain notation)
                                 Example: com.mycompany, art.arcane
                                 Default: art.arcane

    --template TEMPLATE          Template to use. Options:
                                   1 or arcane_template  - Basic Arcane (all platforms)
                                   2 or arcane_beamer    - With Beamer navigation
                                   3 or arcane_dock      - System tray (desktop only)
                                 Default: arcane_template

    --class-name NAME            Base class name (PascalCase)
                                 Default: Auto-derived from app name
                                 Example: MyAwesomeApp

    --work-dir PATH              Working directory for project creation
                                 Default: Current directory

PROJECT STRUCTURE FLAGS:
    --with-models                Create shared models package
    --models                     Alias for --with-models

    --with-server                Create backend server app
    --server                     Alias for --with-server

FIREBASE FLAGS:
    --with-firebase              Enable Firebase integration
    --firebase                   Alias for --with-firebase

    --firebase-project-id ID     Firebase project ID (required if --with-firebase)
                                 Example: my-firebase-project

    --with-cloud-run             Setup Google Cloud Run for server deployment
    --cloud-run                  Alias for --with-cloud-run
                                 (requires --with-server and --with-firebase)

    --service-account-key PATH   Path to Google Cloud service account JSON key
                                 Will be copied to config/keys/ directory

BEHAVIOR FLAGS:
    --non-interactive, -n        Non-interactive mode (fail if required flags missing)
                                 Required flags: --app-name, --org, --template
                                 Also requires --firebase-project-id if using --with-firebase

    --skip-confirm               Skip final confirmation prompts

    --skip-cli-check             Skip CLI tool verification (not recommended)

    --skip-deploy                Skip optional Firebase deployment at end

    --rebuild, -r                Hint to check for existing configuration
                                 Still prompts for directory selection

    --help, -h                   Show this help message

INTERACTIVE MODE EXAMPLES:
    # Basic interactive setup
    ./setup.sh

    # Interactive with some defaults pre-filled
    ./setup.sh --app-name my_app --org com.mycompany

    # Rebuild existing project
    ./setup.sh --rebuild

NON-INTERACTIVE MODE EXAMPLES:
    # Minimal setup (basic app, no Firebase)
    ./setup.sh \\
      --non-interactive \\
      --app-name my_app \\
      --org com.mycompany \\
      --template arcane_template

    # Full stack with Firebase (interactive Firebase steps)
    ./setup.sh \\
      --app-name my_app \\
      --org com.mycompany \\
      --template arcane_beamer \\
      --with-models \\
      --with-server \\
      --with-firebase \\
      --firebase-project-id my-firebase-project

    # Complete non-interactive setup
    ./setup.sh \\
      --non-interactive \\
      --work-dir ~/projects \\
      --app-name my_app \\
      --org com.mycompany \\
      --template arcane_beamer \\
      --with-models \\
      --with-server \\
      --with-firebase \\
      --firebase-project-id my-firebase-project \\
      --with-cloud-run \\
      --skip-deploy

    # Desktop tray app with server
    ./setup.sh \\
      --non-interactive \\
      --app-name my_tray_app \\
      --org art.arcane \\
      --template arcane_dock \\
      --with-server

CONFIGURATION FILE:
    After setup, configuration is saved to config/setup_config.env
    This allows easy rebuilds with the same settings.

    Location: <working_directory>/config/setup_config.env

    To rebuild with saved config:
      1. cd to the directory containing config/setup_config.env
      2. Run: ./setup.sh --rebuild
      3. Confirm rebuild when prompted

WORKFLOW:
    1. Parse command-line flags
    2. Select working directory (FLAG: --work-dir)
    3. Check for existing config file
    4. Verify CLI tools (unless --skip-cli-check)
    5. Gather project configuration (interactive or from flags)
    6. Create projects (client, models, server)
    7. Setup Firebase (if enabled)
    8. Generate configuration files
    9. Setup Docker and deployment scripts
    10. Optional Firebase deployment

REQUIRED TOOLS:
    Always Required:
      - Flutter SDK
      - Dart SDK

    Optional (required for some features):
      - Firebase CLI (for --with-firebase)
      - gcloud CLI (for --with-cloud-run)
      - Docker (for server deployment)

MORE INFO:
    Documentation: https://github.com/arcanearts/arcane_templates
    Issues: https://github.com/arcanearts/arcane_templates/issues

EOF
}

main() {
    # Parse command-line flags first
    parse_flags "$@"

    # Validate flags (if in non-interactive mode)
    validate_flags

    # Apply flags to configuration variables
    apply_flags

    print_banner

    # Check for rebuild flag in remaining args
    local REBUILD_HINT=false
    for arg in "$@"; do
        if [ "$arg" = "--rebuild" ] || [ "$arg" = "-r" ]; then
            REBUILD_HINT=true
            break
        fi
    done

    if [ "$REBUILD_HINT" = true ]; then
        log_info "Rebuild mode - will check for existing configuration after selecting directory"
        echo ""
    elif [ "$FLAG_NON_INTERACTIVE" = true ]; then
        log_info "Non-interactive mode - using provided flags"
        log_info "Creating Flutter app with Arcane UI framework"
        echo ""
    else
        log_info "Welcome to the Arcane Template Setup Wizard!"
        log_info "This wizard will guide you through creating a complete Flutter app"
        log_info "with the Arcane UI framework, including client, models, and server."
        echo ""
    fi

    # Always select working directory first
    select_working_directory

    log_info "Working directory: $(pwd)"
    echo ""

    # Check if configuration exists in this directory
    local REBUILD_MODE=false
    if [ -f "$CONFIG_FILE" ]; then
        log_warning "Found existing configuration: $CONFIG_FILE"
        echo ""

        if load_existing_config; then
            log_success "Configuration loaded successfully"
            echo ""
            show_configuration_summary
            echo ""

            if confirm "Do you want to rebuild the project with these settings?"; then
                REBUILD_MODE=true

                # Check if old project directories exist
                local projects_exist=false
                if [ -d "$APP_NAME" ]; then
                    projects_exist=true
                fi
                if [ "$CREATE_MODELS" = "yes" ] && [ -d "${APP_NAME}_models" ]; then
                    projects_exist=true
                fi
                if [ "$CREATE_SERVER" = "yes" ] && [ -d "${APP_NAME}_server" ]; then
                    projects_exist=true
                fi

                if [ "$projects_exist" = true ]; then
                    log_warning "Existing project directories found!"
                    echo ""
                    if ! confirm "⚠️  This will DELETE and recreate the projects. Continue?"; then
                        log_warning "Rebuild cancelled by user"
                        exit 0
                    fi

                    # Delete existing directories
                    log_info "Removing existing project directories..."
                    rm -rf "$APP_NAME" 2>/dev/null || true
                    [ "$CREATE_MODELS" = "yes" ] && rm -rf "${APP_NAME}_models" 2>/dev/null || true
                    [ "$CREATE_SERVER" = "yes" ] && rm -rf "${APP_NAME}_server" 2>/dev/null || true
                    log_success "Old directories removed"
                    echo ""
                fi
            else
                log_info "Starting fresh setup - existing configuration will be overwritten"
                echo ""
                REBUILD_MODE=false
            fi
        else
            log_warning "Could not load existing configuration - starting fresh setup"
            echo ""
            REBUILD_MODE=false
        fi
    else
        log_info "No existing configuration found - starting fresh setup"
        echo ""
        REBUILD_MODE=false
    fi

    if [ "$FLAG_SKIP_CONFIRM" != true ]; then
        if ! confirm "Ready to continue?"; then
            log_warning "Setup cancelled by user"
            exit 0
        fi
    fi

    # Step 1: Check CLI tools
    if [ "$FLAG_SKIP_CLI_CHECK" != true ]; then
        print_header "Step 1: Checking CLI Tools"
        check_cli_tools || exit 1
    else
        log_info "Skipping CLI tool verification (--skip-cli-check)"
        echo ""
    fi

    # Skip interactive prompts if in rebuild mode or if flags provided all config
    if [ "$REBUILD_MODE" != true ] && [ "$FLAG_NON_INTERACTIVE" != true ]; then
        # Step 2: Gather project information
        print_header "Step 2: Project Configuration"
        gather_project_info

        # Step 3: Project structure options
        print_header "Step 3: Project Structure (Optional)"
        configure_project_structure

        # Step 4: Optional Firebase setup
        print_header "Step 4: Firebase Configuration (Optional)"
        configure_firebase_options

        # Step 5: Show summary and confirm
        print_header "Step 5: Configuration Summary"
        show_configuration_summary

        if [ "$FLAG_SKIP_CONFIRM" != true ]; then
            if ! confirm "Proceed with these settings?"; then
                log_warning "Setup cancelled by user"
                exit 0
            fi
        fi

        # Save configuration
        save_configuration
    elif [ "$FLAG_NON_INTERACTIVE" = true ]; then
        log_info "Using flags - skipping interactive setup"
        echo ""

        # Show summary in non-interactive mode
        show_configuration_summary
        echo ""

        # Save configuration
        save_configuration
    else
        log_info "Using existing configuration - skipping interactive setup"
        echo ""
    fi

    # Step 7: Create client project
    print_header "Step 7: Creating Client Project"
    create_client_app "$APP_NAME" "$ORG_DOMAIN" "$PLATFORMS" || exit 1

    # Step 8: Create models and server (if requested)
    if [ "$CREATE_MODELS" = "yes" ]; then
        print_header "Step 8: Creating Models Package"
        create_models_package "$APP_NAME" || exit 1
    fi

    if [ "$CREATE_SERVER" = "yes" ]; then
        print_header "Step 9: Creating Server App"
        create_server_app "$APP_NAME" "$ORG_DOMAIN" || exit 1
    fi

    # Step 10: Link models to projects (if models package exists)
    if [ "$CREATE_MODELS" = "yes" ]; then
        print_header "Step 10: Linking Models Package"
        link_models_to_projects "$APP_NAME" "$CREATE_SERVER" || exit 1
    fi

    # Step 11: Copy models and server templates
    if [ "$CREATE_MODELS" = "yes" ]; then
        print_header "Step 11: Copying Models Template"
        copy_models_template "$APP_NAME" "$SCRIPT_DIR" "$FIREBASE_PROJECT_ID" || exit 1
    fi

    if [ "$CREATE_SERVER" = "yes" ]; then
        print_header "Step 12: Copying Server Template"
        copy_server_template "$APP_NAME" "$SCRIPT_DIR" "$FIREBASE_PROJECT_ID" "$CREATE_MODELS" || exit 1
    fi

    # Step 13: Copy template files (lib/, pubspec.yaml, assets/, etc.)
    print_header "Step 13: Copying Template Files"
    copy_template_files "$APP_NAME" "$TEMPLATE_DIR" "$FIREBASE_PROJECT_ID" || exit 1

    # Step 14: Add dependencies
    print_header "Step 14: Adding Dependencies"
    add_all_dependencies "$APP_NAME" "$USE_FIREBASE" "$CREATE_MODELS" "$CREATE_SERVER" "$PLATFORMS" || exit 1

    # Step 15: Setup Firebase (if enabled)
    if [ "$USE_FIREBASE" = "yes" ]; then
        print_header "Step 15: Setting Up Firebase"
        setup_firebase_integration
    fi

    # Step 16: Generate configuration files
    print_header "Step 16: Generating Configuration Files"
    if [ "$USE_FIREBASE" = "yes" ]; then
        generate_all_configs "$APP_NAME" "$FIREBASE_PROJECT_ID"
    fi

    # Step 17: Copy template assets
    print_header "Step 17: Setting Up Assets"
    copy_template_assets "$APP_NAME" "$TEMPLATE_DIR"
    update_pubspec_for_assets "$APP_NAME"

    # Step 18: Setup server
    if [ "$CREATE_SERVER" = "yes" ]; then
        print_header "Step 18: Setting Up Server"
        setup_server "$APP_NAME"
    fi

    # Step 19: Clean up test folders
    print_header "Step 19: Cleaning Up Test Folders"
    delete_test_folders "$APP_NAME" "$CREATE_MODELS" "$CREATE_SERVER"

    # Step 20: Optional Firebase deployment
    if [ "$USE_FIREBASE" = "yes" ]; then
        print_header "Step 20: Firebase Deployment (Optional)"
        if [ "$FLAG_SKIP_DEPLOY" = "yes" ]; then
            log_info "Skipping Firebase deployment (--skip-deploy)"
            log_info "You can deploy Firebase resources later using:"
            log_instruction "  firebase deploy --only firestore"
            log_instruction "  firebase deploy --only storage"
            log_instruction "  firebase deploy --only hosting"
        elif [ "$FLAG_NON_INTERACTIVE" = true ]; then
            log_info "Non-interactive mode: Deploying Firebase resources automatically"
            deploy_all_firebase "$APP_NAME"
        elif confirm "Do you want to deploy Firebase resources now?"; then
            deploy_all_firebase "$APP_NAME"
        else
            log_info "You can deploy Firebase resources later using:"
            log_instruction "  firebase deploy --only firestore"
            log_instruction "  firebase deploy --only storage"
            log_instruction "  firebase deploy --only hosting"
        fi
    fi

    # Final summary
    print_header "🎉 Setup Complete! 🎉"
    show_final_summary

    log_success "Your Arcane application is ready!"
}

gather_project_info() {
    log_step "Gathering Project Information"

    # Organization domain
    prompt_with_validation \
        "Organization domain (e.g., com.mycompany, art.arcane)" \
        validate_not_empty \
        ORG_DOMAIN \
        "art.arcane"

    # App name
    prompt_with_validation \
        "App name (lowercase_with_underscores, e.g., my_app)" \
        validate_app_name \
        APP_NAME \
        "my_app"

    # Base class name
    local default_class_name=$(snake_to_pascal "$APP_NAME")
    prompt_with_validation \
        "Base class name (PascalCase, e.g., MyApp)" \
        validate_not_empty \
        BASE_CLASS_NAME \
        "$default_class_name"

    # Template selection
    echo ""
    log_info "Select template:"
    log_instruction "1) arcane_template (no navigation framework)"
    log_instruction "2) arcane_beamer (with Beamer navigation)"
    log_instruction "3) arcane_dock (system tray/menu bar app - desktop only)"
    echo ""

    local template_choice
    read -p "$(echo -e ${CYAN}❯${NC}) Enter choice [1-3] (default: 1): " template_choice
    template_choice="${template_choice:-1}"

    case "$template_choice" in
        1)
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_template"
            TEMPLATE_NAME="arcane_template"
            PLATFORMS="android,ios,web,linux,windows,macos"
            ;;
        2)
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_beamer"
            TEMPLATE_NAME="arcane_beamer"
            PLATFORMS="android,ios,web,linux,windows,macos"
            ;;
        3)
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_dock"
            TEMPLATE_NAME="arcane_dock"
            PLATFORMS="linux,windows,macos"
            log_info "Note: arcane_dock is desktop-only (macOS, Linux, Windows)"
            ;;
        *)
            log_warning "Invalid choice, using arcane_template"
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_template"
            TEMPLATE_NAME="arcane_template"
            PLATFORMS="android,ios,web,linux,windows,macos"
            ;;
    esac

    log_success "Template selected: $TEMPLATE_NAME"
}

configure_project_structure() {
    log_step "Project Structure Configuration"

    log_info "The setup can create a 3-project architecture:"
    log_instruction "• Client app (always created)"
    log_instruction "• Models package (shared data models for client and server)"
    log_instruction "• Server app (backend with Shelf router and Firebase Admin)"
    echo ""

    if confirm "Do you want to create the models package?"; then
        CREATE_MODELS="yes"
    else
        CREATE_MODELS="no"
        log_info "Skipping models package creation"
    fi

    echo ""
    if confirm "Do you want to create the server app?"; then
        CREATE_SERVER="yes"
    else
        CREATE_SERVER="no"
        log_info "Skipping server app creation"
    fi
}

configure_firebase_options() {
    log_step "Firebase Configuration"

    log_info "Firebase integration is optional but recommended for:"
    log_instruction "• Authentication"
    log_instruction "• Cloud Firestore database"
    log_instruction "• Cloud Storage"
    log_instruction "• Analytics and Crashlytics"
    log_instruction "• Web hosting"
    echo ""

    if confirm "Do you want to use Firebase?"; then
        USE_FIREBASE="yes"

        echo ""
        log_instruction "Before continuing, you should:"
        log_instruction "1. Create a Firebase project at: https://console.firebase.google.com/"
        log_instruction "2. Create a Firestore database (use nam5 if US-based)"
        log_instruction "3. Set up authentication providers (Email/Password, Google, Apple)"
        log_instruction "4. Enable billing (upgrade to Blaze plan for some features)"
        echo ""

        press_enter "Press Enter when you've completed Firebase project creation"

        echo ""
        prompt_with_validation \
            "Firebase Project ID (from Firebase Console URL)" \
            validate_firebase_project_id \
            FIREBASE_PROJECT_ID

        echo ""
        # Create config/keys directory BEFORE telling user where to put the file
        ensure_directory "config/keys"
        local absolute_keys_path="$(cd config/keys && pwd)"

        log_instruction "You'll need to create a Google Cloud service account:"
        log_instruction "1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts/create?project=$FIREBASE_PROJECT_ID"
        log_instruction "2. Service account name: ${FIREBASE_PROJECT_ID}-server"
        log_instruction "3. Add role: Basic > Owner"
        log_instruction "4. Create and download JSON key"
        echo ""
        log_instruction "5. Save the downloaded JSON file to this directory:"
        log_success "   $absolute_keys_path"
        echo ""

        # Offer to open the directory for easier access
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if confirm "Open this folder in Finder now?"; then
                open "$absolute_keys_path"
                log_success "Opened in Finder"
                echo ""
            fi
        elif command_exists "xdg-open"; then
            if confirm "Open this folder in file manager now?"; then
                xdg-open "$absolute_keys_path" 2>/dev/null &
                log_success "Opened in file manager"
                echo ""
            fi
        fi

        # Handle service account key
        if [ -n "$FLAG_SERVICE_ACCOUNT_KEY" ]; then
            # Copy provided key file
            if [ -f "$FLAG_SERVICE_ACCOUNT_KEY" ]; then
                cp "$FLAG_SERVICE_ACCOUNT_KEY" "$absolute_keys_path/"
                log_success "Service account key copied to: $absolute_keys_path"
            else
                log_error "Service account key file not found: $FLAG_SERVICE_ACCOUNT_KEY"
                if [ "$FLAG_NON_INTERACTIVE" = true ]; then
                    exit 1
                fi
            fi
        elif [ "$FLAG_NON_INTERACTIVE" = true ]; then
            log_warning "No service account key provided (--service-account-key)"
            log_info "You can add it later to config/keys/"
        elif confirm "Have you created and downloaded the service account key?"; then
            # Keep checking until key is found
            local key_found=false
            while [ "$key_found" = false ]; do
                local key_count
                key_count=$(find config/keys -name "*.json" -type f 2>/dev/null | wc -l)

                if [ "$key_count" -eq 0 ]; then
                    log_warning "No JSON key files found in: $absolute_keys_path"
                    log_instruction "Please add your service account key to the directory above"
                    echo ""
                    if confirm "Have you added the key file?"; then
                        # Will check again in next loop iteration
                        continue
                    else
                        log_info "Skipping service account key verification (you can add it later)"
                        break
                    fi
                else
                    log_success "Service account key found: $(find config/keys -name "*.json" -type f | head -n 1)"
                    key_found=true
                fi
            done
        fi

        echo ""
        if [ "$CREATE_SERVER" = "yes" ]; then
            if confirm "Do you want to setup Google Cloud Run for server deployment?"; then
                SETUP_CLOUD_RUN="yes"

                log_instruction "You'll need to create an Artifact Registry:"
                log_instruction "1. Go to: https://console.cloud.google.com/artifacts/create-repo?project=$FIREBASE_PROJECT_ID"
                log_instruction "2. Name: cloud-run-source-deploy"
                log_instruction "3. Format: Docker, Region: us-central1"
                log_instruction "4. Add cleanup policies (keep 2 versions, delete old)"
                echo ""

                press_enter "Press Enter when you've created the Artifact Registry"
            else
                SETUP_CLOUD_RUN="no"
            fi
        else
            SETUP_CLOUD_RUN="no"
            log_info "Skipping Cloud Run setup (no server app selected)"
        fi

    else
        USE_FIREBASE="no"
        FIREBASE_PROJECT_ID=""
        SETUP_CLOUD_RUN="no"
    fi
}


show_configuration_summary() {
    log_step "Configuration Summary"

    echo ""
    log_info "Project Configuration:"
    log_instruction "  Organization: $ORG_DOMAIN"
    log_instruction "  App Name: $APP_NAME"
    log_instruction "  Base Class: $BASE_CLASS_NAME"
    log_instruction "  Template: $TEMPLATE_NAME"
    log_instruction "  Platforms: $PLATFORMS"
    echo ""

    log_info "Projects to be created:"
    log_instruction "  $(pwd)/$APP_NAME (client app)"
    if [ "$CREATE_MODELS" = "yes" ]; then
        log_instruction "  $(pwd)/${APP_NAME}_models (shared models)"
    fi
    if [ "$CREATE_SERVER" = "yes" ]; then
        log_instruction "  $(pwd)/${APP_NAME}_server (backend server)"
    fi
    echo ""

    if [ "$USE_FIREBASE" = "yes" ]; then
        log_info "Firebase Configuration:"
        log_instruction "  Project ID: $FIREBASE_PROJECT_ID"
        log_instruction "  Cloud Run: $SETUP_CLOUD_RUN"
    else
        log_info "Firebase: Not configured"
    fi
    echo ""
}

save_configuration() {
    log_info "Saving configuration..."

    ensure_directory "config"

    cat > "$CONFIG_FILE" << EOF
# Arcane Template Setup Configuration
# Generated on $(date)

APP_NAME=$APP_NAME
ORG_DOMAIN=$ORG_DOMAIN
BASE_CLASS_NAME=$BASE_CLASS_NAME
TEMPLATE_DIR=$TEMPLATE_DIR
TEMPLATE_NAME=$TEMPLATE_NAME
PLATFORMS=$PLATFORMS
CREATE_MODELS=$CREATE_MODELS
CREATE_SERVER=$CREATE_SERVER
USE_FIREBASE=$USE_FIREBASE
FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID
SETUP_CLOUD_RUN=$SETUP_CLOUD_RUN
EOF

    log_success "Configuration saved to $CONFIG_FILE"
}

setup_firebase_integration() {
    log_step "Setting Up Firebase Integration"

    # Login to Firebase and gcloud
    firebase_login || log_warning "Firebase login failed, you can login manually later"
    gcloud_login || log_warning "gcloud login failed, you can login manually later"

    # Enable Google APIs
    if [ "$SETUP_CLOUD_RUN" = "yes" ]; then
        enable_google_apis "$FIREBASE_PROJECT_ID" || log_warning "Failed to enable some Google APIs"
    fi

    # Configure FlutterFire
    flutterfire_configure "$APP_NAME" "$FIREBASE_PROJECT_ID" || log_warning "FlutterFire configuration failed"
}

show_final_summary() {
    echo ""
    log_success "Project Structure:"
    log_instruction "  $APP_NAME/              - Client application"
    if [ "$CREATE_MODELS" = "yes" ]; then
        log_instruction "  ${APP_NAME}_models/     - Shared models package"
    fi
    if [ "$CREATE_SERVER" = "yes" ]; then
        log_instruction "  ${APP_NAME}_server/     - Server application"
    fi
    if [ "$USE_FIREBASE" = "yes" ]; then
        log_instruction "  config/                 - Configuration files"
    fi
    echo ""

    log_info "Next Steps:"
    echo ""

    log_instruction "1. Run your app:"
    log_instruction "   cd $APP_NAME"
    log_instruction "   flutter run"
    echo ""

    log_instruction "2. Generate app icons and splash screens (when ready):"
    log_instruction "   • Add your icon: $APP_NAME/assets/icon/icon.png (1024x1024)"
    log_instruction "   • Add your splash: $APP_NAME/assets/icon/splash.png"
    log_instruction "   • Generate icons: cd $APP_NAME && dart run gen_icons"
    log_instruction "   • Generate splash: cd $APP_NAME && dart run gen_splash"
    log_instruction "   • Or generate both: cd $APP_NAME && dart run gen_assets"
    echo ""

    if [ "$USE_FIREBASE" = "yes" ]; then
        log_instruction "3. Deploy to Firebase Hosting:"
        log_instruction "   cd $APP_NAME"
        log_instruction "   flutter build web --release"
        log_instruction "   cd .."
        log_instruction "   firebase deploy --only hosting"
        echo ""

        if [ "$SETUP_CLOUD_RUN" = "yes" ] && [ "$CREATE_SERVER" = "yes" ]; then
            log_instruction "4. Deploy server to Google Cloud Run:"
            log_instruction "   cd ${APP_NAME}_server"
            log_instruction "   gcloud builds submit --tag us-central1-docker.pkg.dev/$FIREBASE_PROJECT_ID/cloud-run-source-deploy/${APP_NAME}_server"
            log_instruction "   gcloud run deploy ${APP_NAME}_server --image us-central1-docker.pkg.dev/$FIREBASE_PROJECT_ID/cloud-run-source-deploy/${APP_NAME}_server --region us-central1"
            echo ""
        fi
    fi

    log_info "Documentation:"
    log_instruction "• Setup Guide: $TEMPLATE_DIR/SETUP.md"
    log_instruction "• README: $TEMPLATE_DIR/README.md"
    log_instruction "• Helper Scripts: scripts/README.md"
    echo ""

    log_info "Quick Rebuild:"
    log_instruction "To rebuild this project with the same settings later:"
    log_instruction "  $(cd "$SCRIPT_DIR" && pwd)/setup.sh"
    log_instruction "  (select '$(pwd)' as the directory)"
    log_instruction "  (choose 'yes' when asked to rebuild)"
    log_instruction ""
    log_instruction "Or run: $(cd "$SCRIPT_DIR" && pwd)/setup.sh --rebuild"
    log_instruction "  (still asks for directory, but hints rebuild mode)"
    echo ""

    log_success "Enjoy building with Arcane! 🚀"
}

# Run main function
main "$@"
