#!/bin/bash

# Setup Firebase
# Handles Firebase CLI login and FlutterFire configuration

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

firebase_login() {
    log_step "Firebase Login"

    if ! command_exists "firebase"; then
        log_error "Firebase CLI is not installed"
        log_instruction "Install it with: npm install -g firebase-tools"
        return 1
    fi

    echo ""
    retry_command "Login to Firebase" firebase login
    return $?
}

gcloud_login() {
    log_step "Google Cloud Login"

    if ! command_exists "gcloud"; then
        log_error "Google Cloud CLI is not installed"
        log_instruction "Install it from: https://cloud.google.com/sdk/docs/install"
        return 1
    fi

    echo ""
    retry_command "Login to Google Cloud" gcloud auth login
    return $?
}

flutterfire_configure() {
    local app_name="$1"
    local firebase_project_id="$2"

    log_step "Configuring FlutterFire"

    if ! command_exists "flutterfire"; then
        log_error "FlutterFire CLI is not installed"
        log_instruction "Install it with: dart pub global activate flutterfire_cli"
        return 1
    fi

    cd "$app_name" || return 1

    log_info "This will create firebase_options.dart and register your app with Firebase"
    echo ""

    if retry_command "Configure FlutterFire" flutterfire configure --project="$firebase_project_id" --platforms=android,ios,macos,web,linux,windows; then
        cd .. || return 1
        return 0
    else
        cd .. || return 1
        return 1
    fi
}

enable_google_apis() {
    local firebase_project_id="$1"

    log_step "Enabling Google Cloud APIs"

    if ! command_exists "gcloud"; then
        log_warning "Google Cloud CLI not installed, skipping API enablement"
        return 0
    fi

    echo ""
    log_info "Setting Google Cloud project..."
    retry_command "Set Google Cloud project" gcloud config set project "$firebase_project_id" || return 1

    log_info "Enabling Artifact Registry API..."
    retry_command "Enable Artifact Registry API" gcloud services enable artifactregistry.googleapis.com || return 1

    log_info "Enabling Cloud Run API..."
    retry_command "Enable Cloud Run API" gcloud services enable run.googleapis.com || return 1

    log_success "Google Cloud APIs enabled"
    return 0
}

setup_firebase_hosting_sites() {
    local firebase_project_id="$1"

    log_step "Firebase Hosting Sites Setup"

    log_instruction "To enable beta hosting, you need to:"
    log_instruction "1. Go to: https://console.firebase.google.com/project/$firebase_project_id/hosting/sites"
    log_instruction "2. Scroll down and click 'Add another site'"
    log_instruction "3. Enter site ID: ${firebase_project_id}-beta"
    log_instruction "4. Click 'Add site'"
    echo ""

    press_enter "Press Enter when you have completed this step"

    log_success "Firebase hosting sites setup complete"
    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <app_name> <firebase_project_id>"
        echo "Example: $0 my_app my-firebase-project"
        exit 1
    fi

    firebase_login
    gcloud_login
    enable_google_apis "$2"
    flutterfire_configure "$1" "$2"
fi
