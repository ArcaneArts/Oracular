#!/bin/bash

# Generate Assets
# Generates app icons and splash screens for all platforms

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

generate_launcher_icons() {
    local app_name="$1"

    log_step "Generating Launcher Icons"

    cd "$app_name" || return 1

    # Verify flutter_launcher_icons configuration exists in pubspec.yaml
    if ! grep -q "flutter_launcher_icons:" "pubspec.yaml"; then
        log_error "flutter_launcher_icons configuration not found in pubspec.yaml"
        log_instruction "Please ensure pubspec.yaml contains flutter_launcher_icons configuration"
        cd ..
        return 1
    fi

    # Check if icon file exists
    if [ ! -f "assets/icon/icon.png" ]; then
        log_warning "Icon file not found at assets/icon/icon.png"
        log_instruction "Please add your app icon (1024x1024 PNG) at assets/icon/icon.png"
        cd ..
        return 0
    fi

    echo ""
    if retry_command "Generate launcher icons" dart run flutter_launcher_icons; then
        cd .. || return 1
        return 0
    else
        cd .. || return 1
        return 1
    fi
}

generate_splash_screens() {
    local app_name="$1"

    log_step "Generating Splash Screens"

    cd "$app_name" || return 1

    # Check if splash file exists
    if [ ! -f "assets/icon/splash.png" ]; then
        log_warning "Splash image not found at assets/icon/splash.png"
        log_instruction "Please add your splash image at assets/icon/splash.png"
        cd ..
        return 0
    fi

    echo ""
    if retry_command "Generate splash screens" dart run flutter_native_splash:create; then
        cd .. || return 1
        return 0
    else
        cd .. || return 1
        return 1
    fi
}

configure_platform_versions() {
    local app_name="$1"
    local script_root="${BASH_SOURCE[0]}"

    # Find the repository root by going up from this script location
    local repo_root="$(cd "$(dirname "$script_root")/../../" && pwd)"

    log_step "Configuring Platform Versions"

    echo ""
    retry_command "Set Android minSDK to 23" bash "$repo_root/scripts/set_android_min_sdk.sh" "$app_name" 23 || log_warning "Skipping Android minSDK (failed)"

    retry_command "Set iOS deployment target to 13.0" bash "$repo_root/scripts/set_ios_platform_version.sh" "$app_name" 13.0 || log_warning "Skipping iOS version (failed)"

    retry_command "Set macOS deployment target to 10.15" bash "$repo_root/scripts/set_macos_platform_version.sh" "$app_name" 10.15 || log_warning "Skipping macOS version (failed)"

    log_success "Platform versions configured"
    return 0
}

generate_all_assets() {
    local app_name="$1"
    local generate_icons="${2:-yes}"
    local generate_splash="${3:-yes}"

    # Configure platform versions first
    configure_platform_versions "$app_name"

    # Generate icons if requested
    if [ "$generate_icons" = "yes" ]; then
        generate_launcher_icons "$app_name"
    else
        log_info "Skipping icon generation (disabled in configuration)"
    fi

    # Generate splash screens if requested
    if [ "$generate_splash" = "yes" ]; then
        generate_splash_screens "$app_name"
    else
        log_info "Skipping splash screen generation (disabled in configuration)"
    fi

    log_success "Asset generation complete"
    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <app_name>"
        echo "Example: $0 my_app"
        exit 1
    fi

    generate_all_assets "$1"
fi
