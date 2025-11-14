#!/bin/bash

# Add Dependencies
# Adds all required dependencies to client, models, and server projects

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

add_client_dependencies() {
    local app_name="$1"
    local use_firebase="$2"

    log_step "Configuring Client App Dependencies"

    cd "$app_name" || return 1

    log_info "Template pubspec.yaml already contains core dependencies"

    # Add Firebase dependencies if requested
    if [ "$use_firebase" = "yes" ]; then
        log_info "Adding Firebase dependencies to pubspec.yaml..."

        # Uncomment Firebase-related Arcane packages
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|  # arcane_fluf:|  arcane_fluf:|" pubspec.yaml
            sed -i '' "s|  # arcane_auth:|  arcane_auth:|" pubspec.yaml
            sed -i '' "s|  # fire_crud:|  fire_crud:|" pubspec.yaml
        else
            sed -i "s|  # arcane_fluf:|  arcane_fluf:|" pubspec.yaml
            sed -i "s|  # arcane_auth:|  arcane_auth:|" pubspec.yaml
            sed -i "s|  # fire_crud:|  fire_crud:|" pubspec.yaml
        fi

        # Find the Firebase placeholder line and replace it
        local firebase_deps="  fire_api_flutter: ^1.5.1\n  fire_api: ^1.5.1\n  firebase_core: ^4.0.0\n  firebase_auth: ^6.0.0\n  cloud_firestore: ^6.0.0\n  firebase_analytics: ^12.0.0\n  firebase_crashlytics: ^5.0.0\n  firebase_performance: ^0.11.0\n  firebase_storage: ^13.0.0\n  google_sign_in: ^6.3.0"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|# {all firebase dependencies here}|$firebase_deps|" pubspec.yaml
        else
            sed -i "s|# {all firebase dependencies here}|$firebase_deps|" pubspec.yaml
        fi

        log_success "Firebase dependencies added (including arcane_fluf, arcane_auth, and fire_crud)"
    else
        log_info "Firebase not enabled - arcane_fluf, arcane_auth, and fire_crud will remain commented out"
    fi

    # Run flutter pub get to fetch all dependencies
    echo ""
    if ! retry_command "Get dependencies" flutter pub get; then
        cd ..
        return 1
    fi

    cd .. || return 1

    log_success "Client app dependencies configured"
    return 0
}

add_models_dependencies() {
    local app_name="$1"
    local use_firebase="$2"
    local models_name="${app_name}_models"

    log_step "Adding Dependencies to Models Package"

    cd "$models_name" || return 1

    echo ""
    if ! retry_command "Add core dependencies to models" flutter pub add \
        crypto \
        dart_mappable \
        equatable \
        fire_crud \
        toxic \
        rxdart \
        fast_log \
        jiffy \
        throttled; then
        cd ..
        return 1
    fi

    # Add Firebase dependencies if requested
    if [ "$use_firebase" = "yes" ]; then
        retry_command "Add Firebase dependencies to models" flutter pub add fire_api || log_warning "Skipping Firebase dependencies (failed)"
    fi

    # Add dev dependencies
    retry_command "Add dev dependencies to models" flutter pub add --dev build_runner dart_mappable_builder || log_warning "Skipping dev dependencies (failed)"

    cd .. || return 1

    log_success "Models package dependencies complete"
    return 0
}

add_server_dependencies() {
    local app_name="$1"
    local use_firebase="$2"
    local server_name="${app_name}_server"

    log_step "Adding Dependencies to Server App"

    cd "$server_name" || return 1

    echo ""
    if ! retry_command "Add core dependencies to server" flutter pub add \
        fire_crud \
        shelf \
        shelf_router \
        shelf_cors_headers \
        precision_stopwatch \
        google_cloud \
        http \
        toxic \
        memcached \
        fast_log \
        uuid \
        rxdart \
        crypto \
        dart_jsonwebtoken \
        x509 \
        jiffy; then
        cd ..
        return 1
    fi

    # Add Firebase dependencies if requested
    if [ "$use_firebase" = "yes" ]; then
        retry_command "Add Firebase dependencies to server" flutter pub add fire_api fire_api_dart || log_warning "Skipping Firebase dependencies (failed)"
    fi

    cd .. || return 1

    log_success "Server app dependencies complete"
    return 0
}

add_all_dependencies() {
    local app_name="$1"
    local use_firebase="${2:-no}"
    local create_models="${3:-yes}"
    local create_server="${4:-yes}"

    log_info "Adding dependencies to projects..."
    echo ""

    # Add to client app (always)
    add_client_dependencies "$app_name" "$use_firebase" || return 1

    # Add to models package (if created)
    if [ "$create_models" = "yes" ]; then
        add_models_dependencies "$app_name" "$use_firebase" || return 1
    else
        log_info "Skipping models dependencies (no models package)"
    fi

    # Add to server app (if created)
    if [ "$create_server" = "yes" ]; then
        add_server_dependencies "$app_name" "$use_firebase" || return 1
    else
        log_info "Skipping server dependencies (no server app)"
    fi

    log_success "All dependencies added successfully!"

    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <app_name> [use_firebase]"
        echo "Example: $0 my_app yes"
        exit 1
    fi

    add_all_dependencies "$1" "${2:-no}"
fi
