#!/bin/bash

# Add Dependencies
# Adds all required dependencies to client, models, and server projects

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

add_client_dependencies() {
    local app_name="$1"
    local use_firebase="$2"

    log_step "Adding Dependencies to Client App"

    cd "$app_name" || return 1

    echo ""
    if ! retry_command "Add core Arcane and utility dependencies" flutter pub add \
        arcane \
        arcane_fluf \
        arcane_auth \
        arcane_user \
        toxic \
        toxic_flutter \
        pylon \
        rxdart \
        hive \
        hive_flutter \
        flutter_native_splash \
        serviced \
        fast_log \
        http \
        convert \
        universal_io \
        intl \
        duration \
        decimal \
        rational \
        timeago \
        crypto \
        tinycolor2 \
        url_launcher \
        email_validator \
        tryhard \
        throttled \
        cached_network_image \
        faker \
        artifact; then
        cd ..
        return 1
    fi

    # Add Firebase dependencies if requested
    if [ "$use_firebase" = "yes" ]; then
        retry_command "Add Firebase dependencies" flutter pub add \
            firebase_core \
            firebase_auth \
            cloud_firestore \
            firebase_analytics \
            firebase_crashlytics \
            firebase_performance \
            firebase_storage \
            fire_crud \
            fire_api \
            fire_api_flutter \
            google_sign_in || log_warning "Skipping Firebase dependencies (failed)"
    fi

    # Add dev dependencies
    retry_command "Add dev dependencies" flutter pub add --dev flutter_launcher_icons || log_warning "Skipping dev dependencies (failed)"

    cd .. || return 1

    log_success "Client app dependencies complete"
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

    log_info "Adding dependencies to all projects..."
    echo ""

    # Add to client app
    add_client_dependencies "$app_name" "$use_firebase" || return 1

    # Add to models package
    add_models_dependencies "$app_name" "$use_firebase" || return 1

    # Add to server app
    add_server_dependencies "$app_name" "$use_firebase" || return 1

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
