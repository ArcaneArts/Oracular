#!/bin/bash

# Copy and Customize Templates
# Copies models_template and server_template and replaces placeholders

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

copy_models_template() {
    local app_name="$1"
    local template_root="$2"
    local firebase_project_id="${3:-}"
    local models_name="${app_name}_models"

    log_step "Copying Models Template"

    local models_template="$template_root/models_template"

    if [ ! -d "$models_template" ]; then
        log_warning "Models template not found at $models_template"
        return 1
    fi

    log_info "Copying models template structure..."

    # Copy pubspec.yaml
    if [ -f "$models_template/pubspec.yaml" ]; then
        cp "$models_template/pubspec.yaml" "$models_name/pubspec.yaml" || return 1
        log_success "Copied models pubspec.yaml"
    fi

    # Copy lib directory
    cp -r "$models_template/lib" "$models_name/" || return 1

    # Copy README
    if [ -f "$models_template/README.md" ]; then
        cp "$models_template/README.md" "$models_name/" || return 1
    fi

    log_info "Replacing placeholders in models..."

    # Replace APPNAME with actual app name in all files
    find "$models_name" -type f \( -name "*.dart" -o -name "*.md" -o -name "*.yaml" \) -exec \
        sed -i.bak "s/APPNAME/$app_name/g" {} \; -exec rm {}.bak \;

    # Replace FIREBASE_PROJECT_ID if provided
    if [ -n "$firebase_project_id" ]; then
        log_info "Replacing FIREBASE_PROJECT_ID placeholder in models..."
        find "$models_name" -type f \( -name "*.dart" -o -name "*.yaml" \) -exec \
            sed -i.bak "s/FIREBASE_PROJECT_ID/$firebase_project_id/g" {} \; -exec rm {}.bak \;
        log_success "Firebase project ID configured in models"
    fi

    # Rename the main library file
    if [ -f "$models_name/lib/APPNAME_models.dart" ]; then
        mv "$models_name/lib/APPNAME_models.dart" "$models_name/lib/${models_name}.dart"
    fi

    log_success "Models template copied and customized"
    return 0
}

copy_server_template() {
    local app_name="$1"
    local template_root="$2"
    local firebase_project_id="${3:-FIREBASE_PROJECT_ID}"
    local create_models="${4:-yes}"
    local server_name="${app_name}_server"

    log_step "Copying Server Template"

    local server_template="$template_root/server_template"

    if [ ! -d "$server_template" ]; then
        log_warning "Server template not found at $server_template"
        return 1
    fi

    log_info "Copying server template structure..."

    # Copy pubspec.yaml
    if [ -f "$server_template/pubspec.yaml" ]; then
        cp "$server_template/pubspec.yaml" "$server_name/pubspec.yaml" || return 1

        # Remove models dependency if models package is not being created
        if [ "$create_models" = "no" ]; then
            log_info "Removing models dependency from server (no models package)"
            # Remove the lines containing APPNAME_models dependency (including blank line before it)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # Remove blank line, APPNAME_models:, and path: ../APPNAME_models
                sed -i '' -e '/^$/{ N; /\n  APPNAME_models:/{ N; /path: \.\.\/APPNAME_models/d; }; }' "$server_name/pubspec.yaml"
                # Fallback: remove any remaining APPNAME_models references
                sed -i '' '/APPNAME_models:/d' "$server_name/pubspec.yaml"
                sed -i '' '/path: \.\.\/APPNAME_models/d' "$server_name/pubspec.yaml"
            else
                sed -i -e '/^$/{ N; /\n  APPNAME_models:/{ N; /path: \.\.\/APPNAME_models/d; }; }' "$server_name/pubspec.yaml"
                sed -i '/APPNAME_models:/d' "$server_name/pubspec.yaml"
                sed -i '/path: \.\.\/APPNAME_models/d' "$server_name/pubspec.yaml"
            fi
        fi

        log_success "Copied server pubspec.yaml"
    fi

    # Copy lib directory
    cp -r "$server_template/lib" "$server_name/" || return 1

    # Copy Dockerfile
    if [ -f "$server_template/Dockerfile" ]; then
        cp "$server_template/Dockerfile" "$server_name/" || return 1
    fi

    # Copy deploy script
    if [ -f "$server_template/script_deploy.sh" ]; then
        cp "$server_template/script_deploy.sh" "$server_name/" || return 1
        chmod +x "$server_name/script_deploy.sh"
    fi

    # Copy README
    if [ -f "$server_template/README.md" ]; then
        cp "$server_template/README.md" "$server_name/" || return 1
    fi

    log_info "Replacing placeholders in server..."

    # Replace APPNAME with actual app name
    find "$server_name" -type f \( -name "*.dart" -o -name "*.md" -o -name "*.yaml" -o -name "Dockerfile" -o -name "*.sh" \) -exec \
        sed -i.bak "s/APPNAME/$app_name/g" {} \; -exec rm {}.bak \;

    # Replace FIREBASE_PROJECT_ID
    find "$server_name" -type f \( -name "*.dart" -o -name "*.sh" \) -exec \
        sed -i.bak "s/FIREBASE_PROJECT_ID/$firebase_project_id/g" {} \; -exec rm {}.bak \;

    # Replace AppName class name (PascalCase)
    local class_name=$(snake_to_pascal "$app_name")
    find "$server_name" -type f -name "*.dart" -exec \
        sed -i.bak "s/APPNAMEServer/${class_name}Server/g" {} \; -exec rm {}.bak \;

    log_success "Server template copied and customized"
    return 0
}

copy_cli_template() {
    local app_name="$1"
    local template_root="$2"
    local firebase_project_id="${3:-FIREBASE_PROJECT_ID}"
    local create_models="${4:-no}"
    local create_server="${5:-no}"
    local with_firebase="${6:-no}"

    log_step "Copying CLI Template"

    local cli_template="$template_root/arcane_cli"

    if [ ! -d "$cli_template" ]; then
        log_warning "CLI template not found at $cli_template"
        return 1
    fi

    log_info "Copying CLI template structure..."

    # Copy pubspec.yaml
    if [ -f "$cli_template/pubspec.yaml" ]; then
        cp "$cli_template/pubspec.yaml" "$app_name/pubspec.yaml" || return 1

        # Handle models dependency
        if [ "$create_models" = "yes" ]; then
            log_info "Enabling models dependency in CLI"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's/^  # APPNAME_models:/  APPNAME_models:/' "$app_name/pubspec.yaml"
                sed -i '' 's/^  #   path: \.\.\/APPNAME_models/    path: ..\/APPNAME_models/' "$app_name/pubspec.yaml"
            else
                sed -i 's/^  # APPNAME_models:/  APPNAME_models:/' "$app_name/pubspec.yaml"
                sed -i 's/^  #   path: \.\.\/APPNAME_models/    path: ..\/APPNAME_models/' "$app_name/pubspec.yaml"
            fi
        else
            # Remove models dependency lines entirely
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/# MODELS - Shared data models/d' "$app_name/pubspec.yaml"
                sed -i '' '/# APPNAME_models:/d' "$app_name/pubspec.yaml"
                sed -i '' '/#   path: \.\.\/APPNAME_models/d' "$app_name/pubspec.yaml"
            else
                sed -i '/# MODELS - Shared data models/d' "$app_name/pubspec.yaml"
                sed -i '/# APPNAME_models:/d' "$app_name/pubspec.yaml"
                sed -i '/#   path: \.\.\/APPNAME_models/d' "$app_name/pubspec.yaml"
            fi
        fi

        # Handle Firebase dependencies
        if [ "$with_firebase" = "yes" ]; then
            log_info "Enabling Firebase dependencies in CLI"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's/^  # arcane_fluf:/  arcane_fluf:/' "$app_name/pubspec.yaml"
                sed -i '' 's/^  # firebase_dart:/  firebase_dart:/' "$app_name/pubspec.yaml"
                sed -i '' 's/^  # fire_crud:/  fire_crud:/' "$app_name/pubspec.yaml"
            else
                sed -i 's/^  # arcane_fluf:/  arcane_fluf:/' "$app_name/pubspec.yaml"
                sed -i 's/^  # firebase_dart:/  firebase_dart:/' "$app_name/pubspec.yaml"
                sed -i 's/^  # fire_crud:/  fire_crud:/' "$app_name/pubspec.yaml"
            fi
        else
            # Remove Firebase dependency lines entirely
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/# FIREBASE - Client-side Firebase/d' "$app_name/pubspec.yaml"
                sed -i '' '/# arcane_fluf:/d' "$app_name/pubspec.yaml"
                sed -i '' '/# fire_crud:/d' "$app_name/pubspec.yaml"
                sed -i '' '/# firebase_dart:/d' "$app_name/pubspec.yaml"
            else
                sed -i '/# FIREBASE - Client-side Firebase/d' "$app_name/pubspec.yaml"
                sed -i '/# arcane_fluf:/d' "$app_name/pubspec.yaml"
                sed -i '/# fire_crud:/d' "$app_name/pubspec.yaml"
                sed -i '/# firebase_dart:/d' "$app_name/pubspec.yaml"
            fi
        fi

        log_success "Copied CLI pubspec.yaml"
    fi

    # Copy bin directory
    cp -r "$cli_template/bin" "$app_name/" || return 1

    # Copy lib directory
    cp -r "$cli_template/lib" "$app_name/" || return 1

    # Copy analysis_options.yaml
    if [ -f "$cli_template/analysis_options.yaml" ]; then
        cp "$cli_template/analysis_options.yaml" "$app_name/" || return 1
    fi

    # Copy README
    if [ -f "$cli_template/README.md" ]; then
        cp "$cli_template/README.md" "$app_name/" || return 1
    fi

    log_info "Replacing placeholders in CLI..."

    # Replace APPNAME with actual app name (handles APPNAME_cli -> app_name pattern)
    find "$app_name" -type f \( -name "*.dart" -o -name "*.md" -o -name "*.yaml" \) -exec \
        sed -i.bak "s/APPNAME_cli/${app_name}/g" {} \; -exec rm {}.bak \;
    find "$app_name" -type f \( -name "*.dart" -o -name "*.md" -o -name "*.yaml" \) -exec \
        sed -i.bak "s/APPNAME/$app_name/g" {} \; -exec rm {}.bak \;

    # Replace FIREBASE_PROJECT_ID
    find "$app_name" -type f -name "*.dart" -exec \
        sed -i.bak "s/FIREBASE_PROJECT_ID/$firebase_project_id/g" {} \; -exec rm {}.bak \;

    # Replace AppName class name (PascalCase)
    local class_name=$(snake_to_pascal "$app_name")
    find "$app_name" -type f -name "*.dart" -exec \
        sed -i.bak "s/APPNAMERunner/${class_name}Runner/g" {} \; -exec rm {}.bak \;

    # Rename main library file (APPNAME.dart -> app_name.dart)
    if [ -f "$app_name/lib/APPNAME.dart" ]; then
        mv "$app_name/lib/APPNAME.dart" "$app_name/lib/${app_name}.dart"
    fi

    local main_lib="$app_name/lib/${app_name}.dart"

    # Handle conditional features in main library file
    if [ "$with_firebase" = "yes" ]; then
        log_info "Enabling Firebase imports in CLI"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/^\/\/ FIREBASE_IMPORT: //' "$main_lib"
        else
            sed -i 's/^\/\/ FIREBASE_IMPORT: //' "$main_lib"
        fi
    else
        # Remove Firebase import lines entirely
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^\/\/ FIREBASE_IMPORT:/d' "$main_lib"
        else
            sed -i '/^\/\/ FIREBASE_IMPORT:/d' "$main_lib"
        fi
    fi

    if [ "$create_server" = "yes" ]; then
        log_info "Enabling server commands in CLI"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/^\/\/ SERVER_COMMAND_IMPORT: //' "$main_lib"
            sed -i '' 's/^  \/\/ SERVER_MOUNT: /  /' "$main_lib"
        else
            sed -i 's/^\/\/ SERVER_COMMAND_IMPORT: //' "$main_lib"
            sed -i 's/^  \/\/ SERVER_MOUNT: /  /' "$main_lib"
        fi
    else
        # Remove server command file and references
        rm -f "$app_name/lib/commands/server_command.dart"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^\/\/ SERVER_COMMAND_IMPORT:/d' "$main_lib"
            sed -i '' '/^  \/\/ SERVER_MOUNT:/d' "$main_lib"
        else
            sed -i '/^\/\/ SERVER_COMMAND_IMPORT:/d' "$main_lib"
            sed -i '/^  \/\/ SERVER_MOUNT:/d' "$main_lib"
        fi
    fi

    if [ "$create_models" = "yes" ]; then
        log_info "Enabling models import in CLI"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/^\/\/ MODELS_IMPORT: //' "$main_lib"
        else
            sed -i 's/^\/\/ MODELS_IMPORT: //' "$main_lib"
        fi
    else
        # Remove models import lines entirely
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^\/\/ MODELS_IMPORT:/d' "$main_lib"
        else
            sed -i '/^\/\/ MODELS_IMPORT:/d' "$main_lib"
        fi
    fi

    # Clean up the conditional imports section markers if empty
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/^\/\/ CONDITIONAL_IMPORTS_START/d' "$main_lib"
        sed -i '' '/^\/\/ CONDITIONAL_IMPORTS_END/d' "$main_lib"
    else
        sed -i '/^\/\/ CONDITIONAL_IMPORTS_START/d' "$main_lib"
        sed -i '/^\/\/ CONDITIONAL_IMPORTS_END/d' "$main_lib"
    fi

    log_success "CLI template copied and customized"
    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <app_name> <template_root> [firebase_project_id]"
        echo "Example: $0 my_app /path/to/templates my-firebase-project"
        exit 1
    fi

    copy_models_template "$1" "$2" "${3:-}"
    copy_server_template "$1" "$2" "${3:-FIREBASE_PROJECT_ID}"
fi
