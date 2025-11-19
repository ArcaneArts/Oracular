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
