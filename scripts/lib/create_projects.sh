#!/bin/bash

# Create Projects
# Creates the 3-project architecture: client app, models package, and server

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

create_client_app() {
    local app_name="$1"
    local org="$2"

    log_step "Creating Client App: $app_name"

    if [ -d "$app_name" ]; then
        log_warning "Directory $app_name already exists"
        if ! confirm "Do you want to overwrite it?"; then
            log_error "Cannot continue without creating the app"
            return 1
        fi
    fi

    echo ""
    retry_command "Create client app" flutter create \
        --platforms=android,ios,web,linux,windows,macos \
        -a java \
        -t app \
        --suppress-analytics \
        -e \
        --org "$org" \
        --project-name "$app_name" \
        --overwrite \
        "$app_name"
    return $?
}

create_models_package() {
    local app_name="$1"
    local models_name="${app_name}_models"

    log_step "Creating Models Package: $models_name"

    if [ -d "$models_name" ]; then
        log_warning "Directory $models_name already exists"
        if ! confirm "Do you want to overwrite it?"; then
            log_error "Cannot continue without creating the models package"
            return 1
        fi
    fi

    echo ""
    retry_command "Create models package" flutter create \
        -t package \
        --suppress-analytics \
        --project-name "$models_name" \
        --overwrite \
        "$models_name"
    return $?
}

create_server_app() {
    local app_name="$1"
    local org="$2"
    local server_name="${app_name}_server"

    log_step "Creating Server App: $server_name"

    if [ -d "$server_name" ]; then
        log_warning "Directory $server_name already exists"
        if ! confirm "Do you want to overwrite it?"; then
            log_error "Cannot continue without creating the server"
            return 1
        fi
    fi

    echo ""
    retry_command "Create server app" flutter create \
        --platforms=linux \
        -t app \
        --suppress-analytics \
        -e \
        --org "$org" \
        --project-name "$server_name" \
        --overwrite \
        "$server_name"
    return $?
}

link_models_to_projects() {
    local app_name="$1"
    local models_name="${app_name}_models"
    local server_name="${app_name}_server"

    log_step "Linking Models Package to Client and Server"

    # Add models dependency to client app
    log_info "Adding models dependency to $app_name..."

    # Find the line number where dependencies: section ends (before dev_dependencies or flutter section)
    local insert_line=$(grep -n "^dev_dependencies:" "$app_name/pubspec.yaml" | cut -d: -f1)
    if [ -z "$insert_line" ]; then
        # If no dev_dependencies, insert before flutter section
        insert_line=$(grep -n "^flutter:" "$app_name/pubspec.yaml" | cut -d: -f1)
    fi

    if [ -n "$insert_line" ]; then
        # Insert before the found line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}i\\
\\
  $models_name:\\
    path: ../$models_name
" "$app_name/pubspec.yaml"
        else
            sed -i "${insert_line}i\\\\n  $models_name:\\n    path: ../$models_name" "$app_name/pubspec.yaml"
        fi
        log_success "Added models dependency to client app"
    else
        log_error "Could not find insertion point in pubspec.yaml"
        return 1
    fi

    # Add models dependency to server app
    log_info "Adding models dependency to $server_name..."

    insert_line=$(grep -n "^dev_dependencies:" "$server_name/pubspec.yaml" | cut -d: -f1)
    if [ -z "$insert_line" ]; then
        insert_line=$(grep -n "^flutter:" "$server_name/pubspec.yaml" | cut -d: -f1)
    fi

    if [ -n "$insert_line" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}i\\
\\
  $models_name:\\
    path: ../$models_name
" "$server_name/pubspec.yaml"
        else
            sed -i "${insert_line}i\\\\n  $models_name:\\n    path: ../$models_name" "$server_name/pubspec.yaml"
        fi
        log_success "Added models dependency to server app"
    else
        log_error "Could not find insertion point in pubspec.yaml"
        return 1
    fi

    return 0
}

create_all_projects() {
    local app_name="$1"
    local org="$2"

    log_info "Current directory: $(pwd)"
    log_info "Projects will be created as:"
    log_instruction "  /$app_name - Flutter client application"
    log_instruction "  /${app_name}_models - Shared Dart package"
    log_instruction "  /${app_name}_server - Flutter server application"
    echo ""

    if ! confirm "Create these projects?"; then
        log_warning "Project creation cancelled"
        return 1
    fi

    # Create client app
    create_client_app "$app_name" "$org" || return 1

    # Create models package
    create_models_package "$app_name" || return 1

    # Create server app
    create_server_app "$app_name" "$org" || return 1

    # Link models to projects
    link_models_to_projects "$app_name" || return 1

    log_success "All projects created successfully!"

    return 0
}

delete_test_folders() {
    local app_name="$1"
    local models_name="${app_name}_models"
    local server_name="${app_name}_server"

    log_step "Cleaning Up Test Folders"

    local test_folders=(
        "$models_name/test"
        "$app_name/test"
        "$server_name/test"
    )

    for folder in "${test_folders[@]}"; do
        if [ -d "$folder" ]; then
            log_info "Removing $folder..."
            rm -rf "$folder"
            log_success "Removed $folder"
        fi
    done

    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <app_name> <org>"
        echo "Example: $0 my_app art.arcane"
        exit 1
    fi

    create_all_projects "$1" "$2"
fi
