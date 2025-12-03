#!/bin/bash

# Create Projects
# Creates the 3-project architecture: client app, models package, and server

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

create_client_app() {
    local app_name="$1"
    local org="$2"
    local platforms="${3:-android,ios,web,linux,windows,macos}"

    log_step "Creating Client App: $app_name"

    if [ -d "$app_name" ]; then
        log_warning "Directory $app_name already exists"
        if ! confirm "Do you want to overwrite it?"; then
            log_error "Cannot continue without creating the app"
            return 1
        fi
    fi

    echo ""
    log_info "Creating app with platforms: $platforms"
    retry_command "Create client app" flutter create \
        --platforms="$platforms" \
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

create_cli_app() {
    local app_name="$1"

    log_step "Creating CLI App: $app_name"

    if [ -d "$app_name" ]; then
        log_warning "Directory $app_name already exists"
        if ! confirm "Do you want to overwrite it?"; then
            log_error "Cannot continue without creating the CLI app"
            return 1
        fi
    fi

    echo ""
    retry_command "Create CLI app" dart create \
        -t console \
        --force \
        "$app_name"
    return $?
}

link_models_to_projects() {
    local app_name="$1"
    local create_server="${2:-yes}"
    local is_cli="${3:-no}"
    local models_name="${app_name}_models"
    local server_name="${app_name}_server"

    # Build log message based on what's being created
    local targets="Client"
    [ "$create_server" = "yes" ] && targets="$targets and Server"
    [ "$is_cli" = "yes" ] && targets="CLI"

    log_step "Linking Models Package to $targets"

    # Add models dependency to client/CLI app
    if [ "$is_cli" = "yes" ]; then
        log_info "Adding models dependency to $app_name (CLI)..."

        insert_line=$(grep -n "^dev_dependencies:" "$app_name/pubspec.yaml" | cut -d: -f1)

        if [ -n "$insert_line" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "${insert_line}i\\
\\
  $models_name:\\
    path: ../$models_name
" "$app_name/pubspec.yaml"
            else
                sed -i "${insert_line}i\\\\n  $models_name:\\n    path: ../$models_name" "$app_name/pubspec.yaml"
            fi
            log_success "Added models dependency to CLI app"
        else
            log_error "Could not find insertion point in CLI pubspec.yaml"
            return 1
        fi
    else
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
    fi

    # Add models dependency to server app (if server is being created)
    if [ "$create_server" = "yes" ]; then
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
    fi

    return 0
}

create_all_projects() {
    local app_name="$1"
    local org="$2"
    local platforms="${3:-android,ios,web,linux,windows,macos}"

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
    create_client_app "$app_name" "$org" "$platforms" || return 1

    # Create models package
    create_models_package "$app_name" || return 1

    # Create server app
    create_server_app "$app_name" "$org" || return 1

    # Link models to projects
    link_models_to_projects "$app_name" || return 1

    log_success "All projects created successfully!"

    return 0
}

copy_template_files() {
    local app_name="$1"
    local template_dir="$2"
    local firebase_project_id="${3:-}"
    local template_name="$(basename "$template_dir")"

    log_step "Copying Template Files"

    if [ ! -d "$template_dir" ]; then
        log_error "Template directory not found: $template_dir"
        return 1
    fi

    # Copy lib directory (the source code)
    if [ -d "$template_dir/lib" ]; then
        log_info "Copying lib/ directory from template..."
        rm -rf "$app_name/lib"
        cp -r "$template_dir/lib" "$app_name/"

        # Replace template package name with actual app name in imports
        find "$app_name/lib" -type f -name "*.dart" -exec \
            sed -i.bak "s/package:$template_name/package:$app_name/g" {} \; -exec rm {}.bak \;

        log_success "Template lib/ copied"
    fi

    # Copy pubspec.yaml
    if [ -f "$template_dir/pubspec.yaml" ]; then
        log_info "Copying pubspec.yaml from template..."
        cp "$template_dir/pubspec.yaml" "$app_name/pubspec.yaml"

        # Update name in pubspec
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^name: .*/name: $app_name/" "$app_name/pubspec.yaml"
        else
            sed -i "s/^name: .*/name: $app_name/" "$app_name/pubspec.yaml"
        fi

        # Replace FIREBASE_PROJECT_ID placeholder if provided
        if [ -n "$firebase_project_id" ]; then
            log_info "Replacing FIREBASE_PROJECT_ID placeholder in pubspec.yaml..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/FIREBASE_PROJECT_ID/$firebase_project_id/g" "$app_name/pubspec.yaml"
            else
                sed -i "s/FIREBASE_PROJECT_ID/$firebase_project_id/g" "$app_name/pubspec.yaml"
            fi
            log_success "Firebase project ID configured in pubspec.yaml"
        fi

        log_success "Template pubspec.yaml copied"
    fi

    # Copy analysis_options.yaml if exists
    if [ -f "$template_dir/analysis_options.yaml" ]; then
        log_info "Copying analysis_options.yaml..."
        cp "$template_dir/analysis_options.yaml" "$app_name/"
    fi

    # Copy README if exists
    if [ -f "$template_dir/README.md" ]; then
        log_info "Copying README.md..."
        cp "$template_dir/README.md" "$app_name/"
    fi

    # Copy assets directory if exists
    if [ -d "$template_dir/assets" ]; then
        log_info "Copying assets/ directory..."
        rm -rf "$app_name/assets"
        cp -r "$template_dir/assets" "$app_name/"
    fi

    # Copy platform-specific configurations (for templates like arcane_dock)
    for platform_dir in macos ios android web linux windows; do
        if [ -d "$template_dir/$platform_dir" ]; then
            log_info "Copying $platform_dir/ platform configuration..."
            # Only copy specific files to avoid overwriting critical flutter-generated files

            if [ "$platform_dir" = "macos" ]; then
                # Copy macOS Runner files (Info.plist, entitlements, Swift code, etc.)
                if [ -f "$template_dir/macos/Runner/Info.plist" ]; then
                    cp "$template_dir/macos/Runner/Info.plist" "$app_name/macos/Runner/" 2>/dev/null || true
                fi
                if [ -f "$template_dir/macos/Runner/DebugProfile.entitlements" ]; then
                    cp "$template_dir/macos/Runner/DebugProfile.entitlements" "$app_name/macos/Runner/" 2>/dev/null || true
                fi
                if [ -f "$template_dir/macos/Runner/Release.entitlements" ]; then
                    cp "$template_dir/macos/Runner/Release.entitlements" "$app_name/macos/Runner/" 2>/dev/null || true
                fi
                if [ -f "$template_dir/macos/Runner/MainFlutterWindow.swift" ]; then
                    cp "$template_dir/macos/Runner/MainFlutterWindow.swift" "$app_name/macos/Runner/" 2>/dev/null || true
                    log_info "Copied MainFlutterWindow.swift with launch_at_startup platform code"
                fi
            fi

            if [ "$platform_dir" = "linux" ]; then
                # Copy Linux runner files if they exist
                if [ -f "$template_dir/linux/flutter/CMakeLists.txt" ]; then
                    cp "$template_dir/linux/flutter/CMakeLists.txt" "$app_name/linux/flutter/" 2>/dev/null || true
                fi
            fi
        fi
    done

    log_success "Template files copied successfully"
    return 0
}

copy_template_pubspec() {
    local app_name="$1"
    local template_dir="$2"

    log_step "Copying Template pubspec.yaml"

    if [ ! -f "$template_dir/pubspec.yaml" ]; then
        log_warning "Template pubspec.yaml not found, skipping copy"
        return 0
    fi

    log_info "Copying template pubspec.yaml to preserve comments and configuration..."

    # Backup the generated pubspec
    cp "$app_name/pubspec.yaml" "$app_name/pubspec.yaml.backup"

    # Copy template pubspec
    cp "$template_dir/pubspec.yaml" "$app_name/pubspec.yaml"

    # Update name in pubspec
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^name: .*/name: $app_name/" "$app_name/pubspec.yaml"
    else
        sed -i "s/^name: .*/name: $app_name/" "$app_name/pubspec.yaml"
    fi

    log_success "Template pubspec.yaml copied and customized"
    return 0
}

delete_test_folders() {
    local app_name="$1"
    local create_models="${2:-yes}"
    local create_server="${3:-yes}"
    local is_cli="${4:-no}"
    local models_name="${app_name}_models"
    local server_name="${app_name}_server"

    log_step "Cleaning Up Test Folders"

    # Delete main app test folder (client or CLI)
    if [ -d "$app_name/test" ]; then
        log_info "Removing $app_name/test..."
        rm -rf "$app_name/test"
        log_success "Removed $app_name/test"
    fi

    # Delete models test folder if models package was created
    if [ "$create_models" = "yes" ] && [ -d "$models_name/test" ]; then
        log_info "Removing $models_name/test..."
        rm -rf "$models_name/test"
        log_success "Removed $models_name/test"
    fi

    # Delete server test folder if server app was created
    if [ "$create_server" = "yes" ] && [ -d "$server_name/test" ]; then
        log_info "Removing $server_name/test..."
        rm -rf "$server_name/test"
        log_success "Removed $server_name/test"
    fi

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
