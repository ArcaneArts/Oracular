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
source "$SCRIPT_DIR/scripts/lib/add_dependencies.sh"
source "$SCRIPT_DIR/scripts/lib/setup_firebase.sh"
source "$SCRIPT_DIR/scripts/lib/generate_configs.sh"
source "$SCRIPT_DIR/scripts/lib/generate_assets.sh"
source "$SCRIPT_DIR/scripts/lib/setup_server.sh"
source "$SCRIPT_DIR/scripts/lib/deploy_firebase.sh"

# Configuration file
CONFIG_FILE="config/setup_config.env"

# Main setup function

select_working_directory() {
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

main() {
    print_banner

    log_info "Welcome to the Arcane Template Setup Wizard!"
    log_info "This wizard will guide you through creating a complete Flutter app"
    log_info "with the Arcane UI framework, including client, models, and server."
    echo ""

    # Select working directory
    select_working_directory

    log_info "Working directory: $(pwd)"
    log_instruction "All projects will be created here."
    echo ""

    if ! confirm "Ready to continue?"; then
        log_warning "Setup cancelled by user"
        exit 0
    fi

    # Step 1: Check CLI tools
    print_header "Step 1: Checking CLI Tools"
    check_cli_tools || exit 1

    # Step 2: Gather project information
    print_header "Step 2: Project Configuration"
    gather_project_info

    # Step 3: Optional Firebase setup
    print_header "Step 3: Firebase Configuration (Optional)"
    configure_firebase_options

    # Step 4: Asset generation options
    print_header "Step 4: Asset Generation Options"
    configure_asset_generation

    # Step 5: Show summary and confirm
    print_header "Step 5: Configuration Summary"
    show_configuration_summary

    if ! confirm "Proceed with these settings?"; then
        log_warning "Setup cancelled by user"
        exit 0
    fi

    # Save configuration
    save_configuration

    # Step 6: Create projects
    print_header "Step 6: Creating Projects"
    create_all_projects "$APP_NAME" "$ORG_DOMAIN" || exit 1

    # Step 7: Add dependencies
    print_header "Step 7: Adding Dependencies"
    add_all_dependencies "$APP_NAME" "$USE_FIREBASE" || exit 1

    # Step 8: Setup Firebase (if enabled)
    if [ "$USE_FIREBASE" = "yes" ]; then
        print_header "Step 8: Setting Up Firebase"
        setup_firebase_integration
    fi

    # Step 9: Generate configuration files
    print_header "Step 9: Generating Configuration Files"
    if [ "$USE_FIREBASE" = "yes" ]; then
        generate_all_configs "$APP_NAME" "$FIREBASE_PROJECT_ID"
    fi

    # Step 10: Copy template assets
    print_header "Step 10: Setting Up Assets"
    copy_template_assets "$APP_NAME" "$TEMPLATE_DIR"
    update_pubspec_for_assets "$APP_NAME"

    # Step 11: Configure platform versions and generate assets
    print_header "Step 11: Generating App Icons and Splash Screens"
    generate_all_assets "$APP_NAME" "$GENERATE_ICONS" "$GENERATE_SPLASH"

    # Step 12: Setup server
    print_header "Step 12: Setting Up Server"
    setup_server "$APP_NAME"

    # Step 13: Clean up test folders
    delete_test_folders "$APP_NAME"

    # Step 14: Optional Firebase deployment
    if [ "$USE_FIREBASE" = "yes" ]; then
        print_header "Step 14: Firebase Deployment (Optional)"
        if confirm "Do you want to deploy Firebase resources now?"; then
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
    echo ""

    local template_choice
    read -p "$(echo -e ${CYAN}❯${NC}) Enter choice [1-2] (default: 1): " template_choice
    template_choice="${template_choice:-1}"

    case "$template_choice" in
        1)
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_template"
            TEMPLATE_NAME="arcane_template"
            ;;
        2)
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_beamer"
            TEMPLATE_NAME="arcane_beamer"
            ;;
        *)
            log_warning "Invalid choice, using arcane_template"
            TEMPLATE_DIR="$SCRIPT_DIR/arcane_template"
            TEMPLATE_NAME="arcane_template"
            ;;
    esac

    log_success "Template selected: $TEMPLATE_NAME"
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

        if confirm "Have you created and downloaded the service account key?"; then
            # Keep checking until key is found
            local key_found=false
            while [ "$key_found" = false ]; do
                local key_count=$(find config/keys -name "*.json" -type f 2>/dev/null | wc -l)

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
        USE_FIREBASE="no"
        FIREBASE_PROJECT_ID=""
        SETUP_CLOUD_RUN="no"
    fi
}

configure_asset_generation() {
    log_step "Asset Generation Configuration"

    log_info "The setup can automatically generate app icons and splash screens."
    log_instruction "• App icons: Generated for all platforms from a 1024x1024 PNG"
    log_instruction "• Splash screens: Generated for all platforms from your splash image"
    echo ""

    if confirm "Do you want to generate app icons?"; then
        GENERATE_ICONS="yes"
    else
        GENERATE_ICONS="no"
        log_info "Skipping icon generation (you can run it manually later)"
    fi

    echo ""
    if confirm "Do you want to generate splash screens?"; then
        GENERATE_SPLASH="yes"
    else
        GENERATE_SPLASH="no"
        log_info "Skipping splash generation (you can run it manually later)"
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
    echo ""

    log_info "Projects to be created:"
    log_instruction "  $(pwd)/$APP_NAME"
    log_instruction "  $(pwd)/${APP_NAME}_models"
    log_instruction "  $(pwd)/${APP_NAME}_server"
    echo ""

    if [ "$USE_FIREBASE" = "yes" ]; then
        log_info "Firebase Configuration:"
        log_instruction "  Project ID: $FIREBASE_PROJECT_ID"
        log_instruction "  Cloud Run: $SETUP_CLOUD_RUN"
    else
        log_info "Firebase: Not configured"
    fi
    echo ""

    log_info "Asset Generation:"
    log_instruction "  App Icons: $GENERATE_ICONS"
    log_instruction "  Splash Screens: $GENERATE_SPLASH"
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
USE_FIREBASE=$USE_FIREBASE
FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID
SETUP_CLOUD_RUN=$SETUP_CLOUD_RUN
GENERATE_ICONS=$GENERATE_ICONS
GENERATE_SPLASH=$GENERATE_SPLASH
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
    log_instruction "  ${APP_NAME}_models/     - Shared models package"
    log_instruction "  ${APP_NAME}_server/     - Server application"
    log_instruction "  config/                 - Configuration files"
    echo ""

    log_info "Next Steps:"
    echo ""

    log_instruction "1. Run your app:"
    log_instruction "   cd $APP_NAME"
    log_instruction "   flutter run"
    echo ""

    if [ "$GENERATE_ICONS" = "no" ] || [ "$GENERATE_SPLASH" = "no" ]; then
        log_instruction "2. Generate app icons and splash screens (skipped during setup):"
        if [ "$GENERATE_ICONS" = "no" ]; then
            log_instruction "   • Add your icon: $APP_NAME/assets/icon/icon.png (1024x1024)"
            log_instruction "   • Run: cd $APP_NAME && dart run flutter_launcher_icons"
        fi
        if [ "$GENERATE_SPLASH" = "no" ]; then
            log_instruction "   • Add your splash: $APP_NAME/assets/icon/splash.png"
            log_instruction "   • Run: cd $APP_NAME && dart run flutter_native_splash:create"
        fi
        echo ""
    else
        log_instruction "2. Customize your app icons and splash screen (optional):"
        log_instruction "   • Replace $APP_NAME/assets/icon/icon.png (1024x1024)"
        log_instruction "   • Replace $APP_NAME/assets/icon/splash.png"
        log_instruction "   • Re-run: cd $APP_NAME && dart run flutter_launcher_icons"
        log_instruction "   • Re-run: cd $APP_NAME && dart run flutter_native_splash:create"
        echo ""
    fi

    if [ "$USE_FIREBASE" = "yes" ]; then
        log_instruction "3. Deploy to Firebase Hosting:"
        log_instruction "   cd $APP_NAME"
        log_instruction "   flutter build web --release"
        log_instruction "   cd .."
        log_instruction "   firebase deploy --only hosting"
        echo ""

        if [ "$SETUP_CLOUD_RUN" = "yes" ]; then
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

    log_success "Enjoy building with Arcane! 🚀"
}

# Run main function
main "$@"
