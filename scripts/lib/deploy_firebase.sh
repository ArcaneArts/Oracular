#!/bin/bash

# Deploy Firebase
# Deploys Firestore rules, Storage rules, and web app to Firebase Hosting

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

deploy_firestore() {
    log_step "Deploying Firestore Rules and Indexes"

    if ! command_exists "firebase"; then
        log_error "Firebase CLI is not installed"
        return 1
    fi

    echo ""
    retry_command "Deploy Firestore rules and indexes" firebase deploy --only firestore
    return $?
}

deploy_storage() {
    log_step "Deploying Storage Rules"

    if ! command_exists "firebase"; then
        log_error "Firebase CLI is not installed"
        return 1
    fi

    echo ""
    retry_command "Deploy Storage rules" firebase deploy --only storage
    return $?
}

build_web_app() {
    local app_name="$1"

    log_step "Building Web App for Production"

    cd "$app_name" || return 1

    echo ""
    if retry_command "Build web app for production" flutter build web --release; then
        cd .. || return 1
        return 0
    else
        cd .. || return 1
        return 1
    fi
}

deploy_hosting_release() {
    log_step "Deploying to Firebase Hosting (Release)"

    if ! command_exists "firebase"; then
        log_error "Firebase CLI is not installed"
        return 1
    fi

    echo ""
    retry_command "Deploy to Firebase Hosting (release)" firebase deploy --only hosting:release
    return $?
}

deploy_hosting_beta() {
    log_step "Deploying to Firebase Hosting (Beta)"

    if ! command_exists "firebase"; then
        log_error "Firebase CLI is not installed"
        return 1
    fi

    echo ""
    retry_command "Deploy to Firebase Hosting (beta)" firebase deploy --only hosting:beta
    return $?
}

deploy_all_firebase() {
    local app_name="$1"

    # Deploy Firestore
    deploy_firestore || log_warning "Firestore deployment failed, continuing..."

    # Deploy Storage
    deploy_storage || log_warning "Storage deployment failed, continuing..."

    # Build and deploy web app
    if confirm "Do you want to build and deploy the web app to Firebase Hosting?"; then
        build_web_app "$app_name"

        deploy_hosting_release

        # Beta hosting setup instructions
        echo ""
        log_step "Beta Hosting Site Setup"
        log_info "Firebase Hosting allows multiple sites for staging/preview environments."
        echo ""
        log_instruction "To deploy a beta version, you need to create a second hosting site:"
        log_instruction "1. Open: https://console.firebase.google.com/project/$FIREBASE_PROJECT_ID/hosting/sites"
        log_instruction "2. Scroll down and click 'Add another site'"
        log_instruction "3. Enter Site ID: ${FIREBASE_PROJECT_ID}-beta"
        log_instruction "4. Click 'Add site'"
        echo ""
        log_info "This creates a separate URL for beta testing (${FIREBASE_PROJECT_ID}-beta.web.app)"
        echo ""

        if confirm "Have you created the beta hosting site in Firebase Console?"; then
            echo ""
            if confirm "Do you want to deploy to beta hosting site now?"; then
                deploy_hosting_beta
            fi
        else
            log_info "Skipping beta deployment. You can deploy later using:"
            log_instruction "  firebase deploy --only hosting:beta"
        fi
    fi

    log_success "Firebase deployment complete"
    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <app_name>"
        echo "Example: $0 my_app"
        exit 1
    fi

    deploy_all_firebase "$1"
fi
