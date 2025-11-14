#!/bin/bash

# Generate Configuration Files
# Creates Firebase configuration files (firebase.json, .firebaserc, rules, etc.)

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

generate_firebase_json() {
    local app_name="$1"

    log_info "Generating firebase.json..."

    cat > firebase.json << EOF
{
  "firestore": {
    "rules": "config/firestore.rules",
    "indexes": "config/firestore.indexes.json"
  },
  "storage": {
    "rules": "config/storage.rules"
  },
  "hosting": [
    {
      "public": "$app_name/build/web",
      "target": "release",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    },
    {
      "public": "$app_name/build/web",
      "target": "beta",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ]
}
EOF

    log_success "firebase.json created"
}

generate_firebaserc() {
    local firebase_project_id="$1"

    log_info "Generating .firebaserc..."

    cat > .firebaserc << EOF
{
  "projects": {
    "default": "$firebase_project_id"
  },
  "targets": {
    "$firebase_project_id": {
      "hosting": {
        "release": [
          "$firebase_project_id"
        ],
        "beta": [
          "$firebase_project_id-beta"
        ]
      }
    }
  }
}
EOF

    log_success ".firebaserc created"
}

generate_firestore_rules() {
    ensure_directory "config"

    log_info "Generating Firestore security rules..."

    cat > config/firestore.rules << 'EOF'
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function isAuth(){
      return request.auth != null;
    }

    function getCapabilities(){
      return get(/databases/$(database)/documents/user/$(request.auth.uid)/data/capabilities).data;
    }

    function isAdmin(){
      let d = getCapabilities();
      return isAuth() && d.administrator == true;
    }

    function isUser(id){
      return (isAuth() && request.auth.uid == id) || isAdmin();
    }

    // Default deny all
    match /{document=**} {
      allow read,write: if false;
    }

    // Server commands
    match /command/{command} {
      allow create: if isAuth() && isUser(request.resource.data.user);

      match /response/{response} {
        allow read: if isAuth() && isUser(resource.data.user);
      }
    }

    // User documents
    match /user/{user} {
      allow read,update: if isAdmin();
      allow read,create: if isUser(user);

      match /data/settings {
        allow read,write: if isUser(user);
      }

      match /data/capabilities {
        allow read: if isUser(user);
        allow write: if isAdmin();
      }
    }
  }
}
EOF

    log_success "Firestore rules created"
}

generate_firestore_indexes() {
    ensure_directory "config"

    log_info "Generating Firestore indexes..."

    cat > config/firestore.indexes.json << 'EOF'
{
  "indexes": [],
  "fieldOverrides": []
}
EOF

    log_success "Firestore indexes created"
}

generate_storage_rules() {
    ensure_directory "config"

    log_info "Generating Storage security rules..."

    cat > config/storage.rules << 'EOF'
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Default deny all
    match /{allPaths=**} {
      allow read,write: if false;
    }

    // User files - users can only access their own files
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
EOF

    log_success "Storage rules created"
}

copy_template_assets() {
    local app_name="$1"
    local template_dir="$2"

    log_step "Copying Template Assets"

    # Copy icons and splash assets if they exist in the template
    if [ -d "$template_dir/assets" ]; then
        log_info "Copying assets from template..."

        ensure_directory "$app_name/assets"

        cp -r "$template_dir/assets/"* "$app_name/assets/" 2>/dev/null

        if [ $? -eq 0 ]; then
            log_success "Template assets copied"
        else
            log_warning "No assets to copy from template"
        fi
    fi

    return 0
}

update_pubspec_for_assets() {
    local app_name="$1"

    log_step "Updating pubspec.yaml for Assets"

    local pubspec="$app_name/pubspec.yaml"

    # Check if asset configuration already exists (template pubspecs already have these)
    if grep -q "flutter_launcher_icons:" "$pubspec"; then
        log_info "pubspec.yaml already configured for assets (from template)"
        return 0
    fi

    log_info "Adding asset configuration to pubspec.yaml..."

    # Add assets and configuration (only if not already present)
    cat >> "$pubspec" << 'EOF'

  assets:
    - assets/icon/

flutter_native_splash:
  color: "#230055"
  image: assets/icon/splash.png

flutter_launcher_icons:
  ios: true
  image_path: "assets/icon/icon.png"
  android: "launcher_icon"
  web:
    generate: true
  windows:
    generate: true
  macos:
    generate: true
EOF

    log_success "pubspec.yaml updated with asset configuration"

    # Verify configuration was added
    if ! grep -q "flutter_launcher_icons:" "$pubspec"; then
        log_error "Failed to add flutter_launcher_icons configuration to pubspec.yaml"
        return 1
    fi

    # Run flutter pub get to update dependencies with new config
    log_info "Running flutter pub get to apply changes..."
    echo ""
    cd "$app_name" || return 1

    if ! flutter pub get; then
        log_error "flutter pub get failed"
        cd .. || return 1
        return 1
    fi

    cd .. || return 1
    log_success "Dependencies updated"

    return 0
}

generate_all_configs() {
    local app_name="$1"
    local firebase_project_id="$2"

    log_step "Generating Firebase Configuration Files"

    # Create config directory
    ensure_directory "config"
    ensure_directory "config/keys"

    # Generate Firebase config files
    generate_firebase_json "$app_name"
    generate_firebaserc "$firebase_project_id"
    generate_firestore_rules
    generate_firestore_indexes
    generate_storage_rules

    log_success "All configuration files generated"
    return 0
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <app_name> <firebase_project_id>"
        echo "Example: $0 my_app my-firebase-project"
        exit 1
    fi

    generate_all_configs "$1" "$2"
fi
