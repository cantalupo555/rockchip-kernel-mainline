#!/bin/bash

# Arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

# Simple logging functions
log_info() {
    echo "[CUSTOMIZE] INFO: $1"
}
log_warn() {
    echo "[CUSTOMIZE] WARN: $1"
}
log_error() {
    echo "[CUSTOMIZE] ERROR: $1" >&2
}

# Main function
Main() {
    set -e # Exit immediately if a command fails

    log_info "--- Starting custom image customization ---"
    log_info "Board: $BOARD, Release: $RELEASE, Family: $LINUXFAMILY, Desktop: $BUILD_DESKTOP"

    # Update package list once
    log_info "Updating APT package list..."
    if ! apt-get update; then
        log_error "Failed to execute apt-get update."
        exit 1
    fi

    # Install common packages for all builds (if any)
    # log_info "Installing common packages (e.g., vim, git)..."
    # PACKAGES_TO_INSTALL_COMMON="vim git" # Example
    # if [ -n "$PACKAGES_TO_INSTALL_COMMON" ]; then
    #     log_info "Attempting to install common packages: $PACKAGES_TO_INSTALL_COMMON"
    #     if ! apt-get install -y --no-install-recommends $PACKAGES_TO_INSTALL_COMMON; then
    #         log_error "Failed to install one or more common packages: $PACKAGES_TO_INSTALL_COMMON"
    #         exit 1
    #     else
    #         log_info "Successfully installed common packages."
    #     fi
    # fi

    # --- Install Release-Specific Packages ---
    # This section handles packages specific to certain releases,
    # primarily focusing on Desktop builds but adaptable for Server too.

    PACKAGES_TO_INSTALL="" # Initialize variable

    if [ "$BUILD_DESKTOP" = "yes" ]; then
        log_info "Checking for release-specific packages to install (Desktop)..."
        case "$RELEASE" in
            bookworm)
                log_info "Targeting packages for installation in Bookworm Desktop..."
                # Add packages to install specifically for Bookworm Desktop
                PACKAGES_TO_INSTALL="flatpak gnome-software-plugin-flatpak gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager chrome-gnome-shell gnome-clocks gnome-calendar gnome-calculator gedit eog evince vlc mplayer xdg-utils fonts-liberation evolution yelp font-manager gnome-font-viewer gparted ffmpeg net-tools bmon xfsprogs f2fs-tools vulkan-tools mesa-vulkan-drivers stress-ng cmake cpufrequtils lm-sensors zstd snapd gnome-software wireplumber pipewire pipewire-pulse"
                ;;
            noble | oracular)
                log_info "Targeting packages for installation in Noble/Oracular Desktop..."
                # Add packages to install specifically for Noble/Oracular Desktop
                PACKAGES_TO_INSTALL="flatpak gnome-software-plugin-flatpak gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager chrome-gnome-shell gnome-clocks gnome-calendar gnome-calculator gedit eog evince vlc mplayer xdg-utils fonts-liberation evolution yelp font-manager gnome-font-viewer gparted ffmpeg net-tools bmon xfsprogs f2fs-tools vulkan-tools mesa-vulkan-drivers stress-ng cmake cpufrequtils lm-sensors zstd snapd gnome-software wireplumber pipewire pipewire-pulse"
                ;;
            plucky)
                log_info "Targeting packages for installation in Plucky Desktop (assuming same as Noble for now)..."
                # Add packages to install specifically for Plucky Desktop
                PACKAGES_TO_INSTALL="flatpak gnome-software-plugin-flatpak gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager chrome-gnome-shell gnome-clocks gnome-calendar gnome-calculator gedit eog evince vlc mplayer xdg-utils fonts-liberation evolution yelp font-manager gnome-font-viewer gparted ffmpeg net-tools bmon xfsprogs f2fs-tools vulkan-tools mesa-vulkan-drivers stress-ng cmake cpufrequtils lm-sensors zstd snapd gnome-software wireplumber pipewire pipewire-pulse hardinfo2"
                ;;
            *)
                # Default case for other releases not explicitly listed for Desktop
                log_warn "Release '$RELEASE' has no specific Desktop package installation configuration."
                ;;
        esac
        # Add any other non-release-specific Desktop package installations here if needed
        # Example: PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL package-for-all-desktops"

    else
        log_info "Skipping Desktop-specific package installation."
        # You could add specific Server package installations here if needed
        # log_info "Checking for release-specific packages to install (Server)..."
        # case "$RELEASE" in
        #     bookworm) PACKAGES_TO_INSTALL="apache2 php-fpm";;
        #     noble) PACKAGES_TO_INSTALL="nginx";;
        #     *) log_info "No specific Server packages for release '$RELEASE'";;
        # esac
    fi

    # Proceed with installation only if PACKAGES_TO_INSTALL is not empty
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        log_info "Attempting to install packages for $RELEASE: $PACKAGES_TO_INSTALL"
        # Use '--no-install-recommends' if you want to minimize extra packages
        if ! apt-get install -y --no-install-recommends $PACKAGES_TO_INSTALL; then
            # Installation failure is usually critical, so we exit.
            log_error "Failed to install one or more packages for $RELEASE: $PACKAGES_TO_INSTALL"
            exit 1
        else
            log_info "Successfully installed packages for $RELEASE."

            # --- Add Flathub remote specifically after installing flatpak packages ---
            # Check if flatpak was installed and if we are on Noble, Bookworm or Plucky Desktop
            if [[ ("$RELEASE" == "noble" || "$RELEASE" == "oracular" || "$RELEASE" == "bookworm" || "$RELEASE" == "plucky") && "$BUILD_DESKTOP" == "yes" && "$PACKAGES_TO_INSTALL" == *flatpak* ]]; then
                log_info "Adding Flathub repository for $RELEASE Desktop..."
                # Ensure flatpak command is available before running
                if command -v flatpak &> /dev/null; then
                    if ! flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
                        log_warn "Failed to add Flathub repository. Flatpak apps may not be available in Software Center."
                        # Decide if this is a critical error (exit 1) or just a warning. Let's warn for now.
                        # exit 1
                    else
                        log_info "Flathub repository added successfully."
                       # --- Verification Step ---
                       log_info "Verifying Flatpak remotes..."
                       if ! flatpak remotes -d; then
                           log_warn "Failed to list Flatpak remotes."
                       fi
                       # --- End Verification Step ---

                       # --- Install Firefox via Flatpak (COMMENTED OUT) ---
                       # log_info "Attempting to install Firefox via Flatpak..."
                       # # Explicitly set TMPDIR in case the default location lacks O_TMPFILE support
                       # # /var/tmp is often used, let's try explicitly setting it first.
                       # export TMPDIR="/var/tmp"
                       # log_info "Using TMPDIR=$TMPDIR for flatpak install."
                       # # Use -y or --noninteractive to avoid prompts during build
                       # if ! flatpak install -y --noninteractive flathub org.mozilla.firefox; then
                       #     log_warn "Failed to install Firefox via Flatpak (TMPDIR=$TMPDIR). Check network or Flathub status, or filesystem support for O_TMPFILE."
                       #     # If /var/tmp didn't work, maybe try /tmp next time:
                       #     # log_warn "Consider trying export TMPDIR=/tmp instead."
                       #
                       #     # Decide if this is critical (exit 1) or just a warning.
                       #     # exit 1
                       # else
                       #     log_info "Firefox successfully installed via Flatpak."
                       # fi
                       # Clean up environment variable if desired (optional)
                       # unset TMPDIR
                       # --- End Firefox Flatpak Install ---

                   fi
                else
                    log_warn "flatpak command not found after installation. Cannot add Flathub repository or install Flatpak apps."
                fi
            fi
            # --- End Flathub remote add ---

            # --- Install Vivaldi Browser (Noble/Bookworm/Plucky Desktop Only) ---
            if [[ ("$RELEASE" == "noble" || "$RELEASE" == "oracular" || "$RELEASE" == "bookworm" || "$RELEASE" == "plucky") && "$BUILD_DESKTOP" == "yes" ]]; then
                log_info "Attempting to install Vivaldi Browser for $RELEASE Desktop..."
                VIVALDI_URL="https://downloads.vivaldi.com/stable/vivaldi-stable_7.3.3635.11-1_arm64.deb"
                VIVALDI_DEB="/tmp/vivaldi-stable_arm64.deb" # Use /tmp for the download

                log_info "Downloading Vivaldi from $VIVALDI_URL..."
                if ! wget --no-verbose -O "$VIVALDI_DEB" "$VIVALDI_URL"; then # Added --no-verbose
                    log_error "Failed to download Vivaldi from $VIVALDI_URL."
                    # Decide if this is fatal. Let's assume yes for now.
                    exit 1
                else
                    log_info "Vivaldi downloaded successfully to $VIVALDI_DEB."

                    log_info "Installing Vivaldi from $VIVALDI_DEB..."
                    # Use apt-get install to handle dependencies automatically
                    if ! apt-get install -y "$VIVALDI_DEB"; then
                        log_error "Failed to install Vivaldi from $VIVALDI_DEB. Dependencies might be missing or broken."
                        rm -f "$VIVALDI_DEB" # Clean up even on failure
                        exit 1
                    else
                        log_info "Vivaldi installed successfully."
                        rm -f "$VIVALDI_DEB" # Clean up after successful installation
                    fi
                fi
            fi
            # --- End Vivaldi Browser Install ---

            # --- Install AppIndicator Extension (Manual - Noble/Bookworm/Plucky Desktop Only) ---
            if [[ ("$RELEASE" == "noble" || "$RELEASE" == "oracular" || "$RELEASE" == "bookworm" || "$RELEASE" == "plucky") && "$BUILD_DESKTOP" == "yes" && "$PACKAGES_TO_INSTALL" == *gnome-shell* ]]; then
                log_info "Attempting to install AppIndicator extension for $RELEASE Desktop..."

                # Ensure unzip is installed (should be from package list above)
                if ! command -v unzip &> /dev/null; then
                    log_error "unzip command not found, but required for extension install. Stopping."
                    exit 1
                fi

                local APPINDICATOR_EXT_UUID="appindicatorsupport@rgcjonas.gmail.com"
                local APPINDICATOR_EXT_URL="" # URL will be set based on release
                local APPINDICATOR_EXT_ZIP="/tmp/appindicator.zip"
                local APPINDICATOR_EXT_DIR="/usr/share/gnome-shell/extensions/${APPINDICATOR_EXT_UUID}"

                # Select URL based on Release (GNOME version)
                if [[ "$RELEASE" == "noble" || "$RELEASE" == "oracular" ]]; then
                    # v59 for GNOME 46/47 (Noble/Oracular)
                    APPINDICATOR_EXT_URL="https://extensions.gnome.org/extension-data/appindicatorsupportrgcjonas.gmail.com.v59.shell-extension.zip"
                    log_info "Selected AppIndicator v59 for Noble/Oracular (GNOME 46/47)."
                elif [[ "$RELEASE" == "bookworm" ]]; then
                    # v53 for GNOME 43 (Bookworm)
                    APPINDICATOR_EXT_URL="https://extensions.gnome.org/extension-data/appindicatorsupportrgcjonas.gmail.com.v53.shell-extension.zip"
                    log_info "Selected AppIndicator v53 for Bookworm (GNOME 43)."
                elif [[ "$RELEASE" == "plucky" ]]; then
                    log_info "AppIndicator not yet supported for GNOME 48 (Plucky)."
                    continue
                else
                    # Should not happen due to outer if, but good practice
                    log_error "Unsupported release '$RELEASE' for AppIndicator installation."
                    exit 1
                fi

                log_info "Downloading AppIndicator from $APPINDICATOR_EXT_URL..."
                if ! wget --no-verbose -O "$APPINDICATOR_EXT_ZIP" "$APPINDICATOR_EXT_URL"; then
                    log_error "Failed to download AppIndicator extension from $APPINDICATOR_EXT_URL."
                    rm -f "$APPINDICATOR_EXT_ZIP" # Clean up partial download
                    exit 1 # Consider this fatal
                fi

                log_info "Creating extension directory: $APPINDICATOR_EXT_DIR"
                if ! mkdir -p "$APPINDICATOR_EXT_DIR"; then
                    log_error "Failed to create extension directory: $APPINDICATOR_EXT_DIR"
                    rm -f "$APPINDICATOR_EXT_ZIP"
                    exit 1
                fi

                log_info "Extracting AppIndicator to $APPINDICATOR_EXT_DIR..."
                if ! unzip -oq "$APPINDICATOR_EXT_ZIP" -d "$APPINDICATOR_EXT_DIR"; then # Added -o to overwrite without prompt
                    log_error "Failed to extract AppIndicator extension to $APPINDICATOR_EXT_DIR."
                    rm -f "$APPINDICATOR_EXT_ZIP"
                    rm -rf "$APPINDICATOR_EXT_DIR" # Clean up potentially broken extraction
                    exit 1
                fi

                # --- Set Permissions ---
                log_info "Setting correct permissions for $APPINDICATOR_EXT_DIR..."
                if ! chmod -R a+rX "$APPINDICATOR_EXT_DIR"; then
                    log_error "Failed to set permissions for $APPINDICATOR_EXT_DIR."
                    # Consider adding 'exit 1' if permissions are critical
                fi
                # --- End Set Permissions ---

                log_info "AppIndicator extension files installed successfully to $APPINDICATOR_EXT_DIR."
                rm -f "$APPINDICATOR_EXT_ZIP" # Clean up downloaded zip

                # Enabling happens below in the dconf section modification
            fi
            # --- End AppIndicator Install ---

            # --- Install Clipboard Indicator Extension (Manual - Noble/Bookworm/Plucky Desktop Only) ---
            if [[ ("$RELEASE" == "noble" || "$RELEASE" == "oracular" || "$RELEASE" == "bookworm" || "$RELEASE" == "plucky") && "$BUILD_DESKTOP" == "yes" && "$PACKAGES_TO_INSTALL" == *gnome-shell* ]]; then
                log_info "Attempting to install Clipboard Indicator extension for $RELEASE Desktop..."

                # Ensure unzip is installed (should be from package list above)
                if ! command -v unzip &> /dev/null; then
                    log_error "unzip command not found, but required for extension install. Stopping."
                    exit 1
                fi

                local CLIPBOARD_EXT_UUID="clipboard-indicator@tudmotu.com"
                local CLIPBOARD_EXT_URL="" # URL will be set based on release
                local CLIPBOARD_EXT_ZIP="/tmp/clipboard-indicator.zip"
                local CLIPBOARD_EXT_DIR="/usr/share/gnome-shell/extensions/${CLIPBOARD_EXT_UUID}"

                # Select URL based on Release (GNOME version)
                if [[ "$RELEASE" == "noble" || "$RELEASE" == "oracular" ]]; then
                    # v68 for GNOME 46/47 (Noble/Oracular)
                    CLIPBOARD_EXT_URL="https://extensions.gnome.org/extension-data/clipboard-indicatortudmotu.com.v68.shell-extension.zip"
                    log_info "Selected Clipboard Indicator v68 for Noble/Oracular (GNOME 46/47)."
                elif [[ "$RELEASE" == "bookworm" ]]; then
                    # v47 for GNOME 43 (Bookworm)
                    CLIPBOARD_EXT_URL="https://extensions.gnome.org/extension-data/clipboard-indicatortudmotu.com.v47.shell-extension.zip"
                    log_info "Selected Clipboard Indicator v47 for Bookworm (GNOME 43)."
                elif [[ "$RELEASE" == "plucky" ]]; then
                    # v68 for GNOME 48 (Plucky)
                    CLIPBOARD_EXT_URL="https://extensions.gnome.org/extension-data/clipboard-indicatortudmotu.com.v68.shell-extension.zip"
                    log_info "Selected Clipboard Indicator v68 (PLACEHOLDER) for Plucky (GNOME 48)."
                else
                    # Should not happen due to outer if, but good practice
                    log_error "Unsupported release '$RELEASE' for Clipboard Indicator installation."
                    exit 1
                fi

                log_info "Downloading Clipboard Indicator from $CLIPBOARD_EXT_URL..."
                if ! wget --no-verbose -O "$CLIPBOARD_EXT_ZIP" "$CLIPBOARD_EXT_URL"; then
                    log_error "Failed to download Clipboard Indicator extension from $CLIPBOARD_EXT_URL."
                    rm -f "$CLIPBOARD_EXT_ZIP" # Clean up partial download
                    exit 1 # Consider this fatal
                fi

                log_info "Creating extension directory: $CLIPBOARD_EXT_DIR"
                if ! mkdir -p "$CLIPBOARD_EXT_DIR"; then
                    log_error "Failed to create extension directory: $CLIPBOARD_EXT_DIR"
                    rm -f "$CLIPBOARD_EXT_ZIP"
                    exit 1
                fi

                log_info "Extracting Clipboard Indicator to $CLIPBOARD_EXT_DIR..."
                if ! unzip -oq "$CLIPBOARD_EXT_ZIP" -d "$CLIPBOARD_EXT_DIR"; then # Added -o to overwrite without prompt
                    log_error "Failed to extract Clipboard Indicator extension to $CLIPBOARD_EXT_DIR."
                    rm -f "$CLIPBOARD_EXT_ZIP"
                    rm -rf "$CLIPBOARD_EXT_DIR" # Clean up potentially broken extraction
                    exit 1
                fi

                # --- Set Permissions ---
                log_info "Setting correct permissions for $CLIPBOARD_EXT_DIR..."
                if ! chmod -R a+rX "$CLIPBOARD_EXT_DIR"; then
                    log_error "Failed to set permissions for $CLIPBOARD_EXT_DIR."
                    # Consider adding 'exit 1' if permissions are critical
                fi
                # --- End Set Permissions ---

                log_info "Clipboard Indicator extension files installed successfully to $CLIPBOARD_EXT_DIR."
                rm -f "$CLIPBOARD_EXT_ZIP" # Clean up downloaded zip

                # Enabling happens below in the dconf section modification
            fi
            # --- End Clipboard Indicator Install ---

            # --- Install Dash to Dock Extension (Manual - Noble/Bookworm/Plucky Desktop Only) ---
            if [[ ("$RELEASE" == "noble" || "$RELEASE" == "oracular" || "$RELEASE" == "bookworm" || "$RELEASE" == "plucky") && "$BUILD_DESKTOP" == "yes" && "$PACKAGES_TO_INSTALL" == *gnome-shell* ]]; then
                log_info "Attempting to install Dash to Dock extension for $RELEASE Desktop..."

                # Ensure unzip is installed
                if ! command -v unzip &> /dev/null; then
                    log_error "unzip command not found, but required for extension install. Stopping."
                    exit 1
                fi

                local DOCK_EXT_UUID="dash-to-dock@micxgx.gmail.com"
                local DOCK_EXT_URL=""
                local DOCK_EXT_ZIP="/tmp/dash-to-dock.zip"
                local DOCK_EXT_DIR="/usr/share/gnome-shell/extensions/${DOCK_EXT_UUID}"

                # Select URL based on Release (GNOME version)
                if [[ "$RELEASE" == "noble" || "$RELEASE" == "oracular" ]]; then
                    # v100 for GNOME 46/47 (Noble/Oracular)
                    DOCK_EXT_URL="https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.v100.shell-extension.zip"
                    log_info "Selected Dash to Dock v100 for Noble/Oracular (GNOME 46/47)."
                elif [[ "$RELEASE" == "bookworm" ]]; then
                    # v84 for GNOME 43 (Bookworm)
                    DOCK_EXT_URL="https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.v84.shell-extension.zip"
                    log_info "Selected Dash to Dock v84 for Bookworm (GNOME 43)."
                elif [[ "$RELEASE" == "plucky" ]]; then
                    # v100 for GNOME 48 (Plucky)
                    DOCK_EXT_URL="https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.v100.shell-extension.zip"
                    log_info "Selected Dash to Dock v100 (PLACEHOLDER) for Plucky (GNOME 48)."
                else
                    # Should not happen due to outer if, but good practice
                    log_error "Unsupported release '$RELEASE' for Dash to Dock installation."
                    exit 1
                fi

                log_info "Downloading Dash to Dock extension from $DOCK_EXT_URL..."
                if ! wget --no-verbose -O "$DOCK_EXT_ZIP" "$DOCK_EXT_URL"; then
                    log_error "Failed to download Dash to Dock extension from $DOCK_EXT_URL."
                    rm -f "$DOCK_EXT_ZIP" # Clean up partial download
                    exit 1 # Consider this fatal
                fi

                log_info "Creating extension directory: $DOCK_EXT_DIR"
                # Use -p to create parent directories if needed, although /usr/share/gnome-shell/extensions should exist
                if ! mkdir -p "$DOCK_EXT_DIR"; then
                    log_error "Failed to create extension directory: $DOCK_EXT_DIR"
                    rm -f "$DOCK_EXT_ZIP"
                    exit 1
                fi

                log_info "Extracting Dash to Dock extension to $DOCK_EXT_DIR..."
                # Use -o to overwrite files without prompting, useful if re-running
                if ! unzip -oq "$DOCK_EXT_ZIP" -d "$DOCK_EXT_DIR"; then
                    log_error "Failed to extract Dash to Dock extension to $DOCK_EXT_DIR."
                    rm -f "$DOCK_EXT_ZIP"
                    rm -rf "$DOCK_EXT_DIR" # Clean up potentially broken extraction
                    exit 1
                fi

                # --- Set Permissions ---
                log_info "Setting correct permissions for $DOCK_EXT_DIR..."
                if ! chmod -R a+rX "$DOCK_EXT_DIR"; then # Give read permission to all, and execute permission to all for directories/already executable files
                    log_error "Failed to set permissions for $DOCK_EXT_DIR."
                    # You might want to add 'exit 1' here if permissions are critical
                fi
                # --- End Set Permissions ---

                log_info "Dash to Dock extension files installed successfully to $DOCK_EXT_DIR."
                rm -f "$DOCK_EXT_ZIP" # Clean up downloaded zip

                # Enabling happens below in the dconf section modification
            fi
            # --- End Dash to Dock Install ---

            # --- Apply GNOME Default Settings via dconf Overrides ---
            if [[ "$BUILD_DESKTOP" == "yes" && "$PACKAGES_TO_INSTALL" == *gnome-shell* ]]; then # Check if GNOME is likely installed
                log_info "Applying GNOME default settings via dconf overrides..."

                # Remove potentially conflicting default background settings file from Armbian base
                log_info "Removing existing dconf background file 00-bg (if it exists)..."
                rm -f /etc/dconf/db/local.d/00-bg

                # Ensure dconf tools are available (should be with gnome-shell)
                if command -v dconf &> /dev/null; then
                    local DCONF_DIR="/etc/dconf/db/local.d"
                    local DCONF_FILE="$DCONF_DIR/90-armbian-gnome-defaults"
                    local WALLPAPER_LIGHT=""
                    local WALLPAPER_DARK=""

                    # --- Define Wallpaper Paths based on Release ---
                    if [[ "$RELEASE" == "noble" || "$RELEASE" == "oracular" || "$RELEASE" == "plucky" ]]; then
                        log_info "Setting Ubuntu default wallpapers for Noble/Oracular/Plucky."
                        WALLPAPER_LIGHT="file:///usr/share/backgrounds/warty-final-ubuntu.png"
                        WALLPAPER_DARK="file:///usr/share/backgrounds/ubuntu-wallpaper-d.png"
                        # Check existence for Noble/Oracular/Plucky
                        if [ ! -f /usr/share/backgrounds/warty-final-ubuntu.png ]; then
                            log_warn "Ubuntu light wallpaper not found for Noble/Oracular/Plucky, using fallback."
                            WALLPAPER_LIGHT=""
                        fi
                        if [ ! -f /usr/share/backgrounds/ubuntu-wallpaper-d.png ]; then
                            log_warn "Ubuntu dark wallpaper not found for Noble/Oracular/Plucky, using fallback."
                            WALLPAPER_DARK=""
                        fi
                    elif [[ "$RELEASE" == "bookworm" ]]; then
                        log_info "Setting Debian default wallpaper for Bookworm."
                        # Debian 12 Emerald theme wallpaper (adjust path/resolution if needed)
                        local DEBIAN_WALLPAPER_PATH="/usr/share/desktop-base/emerald-theme/wallpaper/contents/images/1920x1080.png"
                        if [ -f "$DEBIAN_WALLPAPER_PATH" ]; then
                            WALLPAPER_LIGHT="file://${DEBIAN_WALLPAPER_PATH}"
                            # Use the same for dark theme, as Debian doesn't have a distinct default dark one usually
                            WALLPAPER_DARK="file://${DEBIAN_WALLPAPER_PATH}"
                        else
                            log_warn "Debian default wallpaper '$DEBIAN_WALLPAPER_PATH' not found for Bookworm, using fallback."
                            WALLPAPER_LIGHT=""
                            WALLPAPER_DARK=""
                        fi
                    else
                        log_warn "Wallpaper paths not defined for release '$RELEASE', using fallback."
                        WALLPAPER_LIGHT=""
                        WALLPAPER_DARK=""
                    fi
                    # --- End Wallpaper Path Definition ---

                    log_info "Creating dconf override directory: $DCONF_DIR"
                    mkdir -p "$DCONF_DIR"

                    log_info "Creating dconf override file: $DCONF_FILE"
                    # Use cat with heredoc to write the settings
                    # Note: system-monitor and workspace-indicator are part of gnome-shell-extensions package
                    cat << EOF > "$DCONF_FILE"
[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop', 'vivaldi-stable.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Software.desktop']

# Enable extensions by default if they were installed
# Ensure these UUIDs match the installed extensions
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'clipboard-indicator@tudmotu.com', 'dash-to-dock@micxgx.gmail.com', 'system-monitor@gnome-shell-extensions.gcampax.github.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com']

[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-uri='$WALLPAPER_LIGHT'
picture-uri-dark='$WALLPAPER_DARK'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='$WALLPAPER_LIGHT'
picture-uri-dark='$WALLPAPER_DARK'
picture-options='zoom'
EOF
                    log_info "Updating dconf database..."
                    if ! dconf update; then
                        log_error "Failed to update dconf database. GNOME settings may not be applied."
                        # Decide if this is fatal (exit 1) or just a warning
                    else
                        log_info "dconf database updated successfully."
                    fi
                else
                    log_warn "dconf command not found. Cannot apply GNOME default settings."
                fi
            fi
            # --- End GNOME Default Settings ---

            # Unlike removal, autoremove is usually not needed immediately after install
        fi
    else
        # Log message if no packages were targeted for the current release/build type
        log_info "No specific packages marked for installation for this phase."
    fi
    # --- End Install Release-Specific Packages ---

    # --- Remove Release-Specific Unwanted Packages ---
    log_info "Checking for release-specific packages to remove..."

    PACKAGES_TO_REMOVE="" # Initialize variable, will be set based on release

    case "$RELEASE" in
        noble | oracular | bookworm | plucky) # apply the same removals for Noble/Oracular, Bookworm, and Plucky
            log_info "Targeting packages for removal in $RELEASE..."
            # List packages to remove specifically for these releases
            PACKAGES_TO_REMOVE="synaptic xarchiver mc"
            ;;
        *)
            # Default case for other releases not explicitly listed
            log_info "No specific package removal configuration for release '$RELEASE'."
            ;;
    esac

    # Proceed with removal only if PACKAGES_TO_REMOVE is not empty
    if [ -n "$PACKAGES_TO_REMOVE" ]; then
        log_info "Attempting to purge packages for $RELEASE: $PACKAGES_TO_REMOVE"
        # Use 'purge' to remove packages and their configuration files.
        # Use 'remove' if you want to keep configuration files.
        if ! apt-get purge -y $PACKAGES_TO_REMOVE; then
            # Log an error but decide if you want to stop the build (exit 1)
            # or just warn and continue. For now, let's just warn.
            log_warn "Could not purge one or more packages for $RELEASE: $PACKAGES_TO_REMOVE. Continuing build."
            # If removal failure is critical, uncomment the next line:
            # exit 1
        else
            log_info "Successfully purged packages for $RELEASE."
            # Run autoremove AFTER successful purge to clean up dependencies
            log_info "Running apt-get autoremove..."
            if ! apt-get autoremove -y; then
                log_warn "apt-get autoremove failed. Continuing build."
                # If autoremove failure is critical, uncomment the next line:
                # exit 1
            else
                log_info "apt-get autoremove completed."
            fi
        fi
    else
        # Log message if no packages were targeted for the current release
        log_info "No packages marked for removal for release '$RELEASE'."
    fi
    # --- End Remove Release-Specific Unwanted Packages ---

    # --- Remove Armbian Specific Backgrounds ---
    if [[ "$BUILD_DESKTOP" == "yes" ]]; then
        log_info "Removing Armbian specific background directories..."
        rm -rf /usr/share/backgrounds/armbian
        rm -rf /usr/share/backgrounds/armbian-lightdm
        log_info "Armbian background directories removed (if they existed)."
    fi
    # --- End Remove Armbian Specific Backgrounds ---

    # --- Conditional Examples (Commented Out) ---

    # Example: Execute specific commands for a board (BOARD)
    # if [ "$BOARD" = "orangepi5-plus" ]; then
    #     log_info "Applying specific configuration for Orange Pi 5 Plus..."
    #     # Specific commands here, for example:
    #     # apt install -y pacote-especifico-opi5plus
    #     # echo "dtoverlay=spi-spidev" >> /boot/armbianEnv.txt # Hypothetical example
    # fi

    # --- End of Commented Examples ---

    # --- Section to copy overlay configuration files...
    log_info "Copying overlay configuration files..."
    OVERLAY_DIR="/tmp/overlay"

    # Check and copy armbian-zram-config to /etc/default/
    if [ -f "${OVERLAY_DIR}/armbian-zram-config" ]; then
        DEST_DIR="/etc/default"
        mkdir -p "${DEST_DIR}" # Create destination directory if it doesn't exist
        if cp "${OVERLAY_DIR}/armbian-zram-config" "${DEST_DIR}/armbian-zram-config"; then
            log_info "armbian-zram-config copied successfully to ${DEST_DIR}."
            # Set appropriate permissions (e.g., read for all, write for owner)
            chmod 644 "${DEST_DIR}/armbian-zram-config"
            # Optional: Enable the service if necessary (if the service exists)
            if command -v systemctl &> /dev/null; then
                if systemctl is-enabled armbian-zram-config &> /dev/null; then
                    log_info "Service armbian-zram-config is already enabled."
                else
                    systemctl enable armbian-zram-config
                    log_info "Service armbian-zram-config enabled."
                fi
            else
                log_warn "systemctl not found. Cannot enable the service automatically."
            fi
        else
            log_warn "Failed to copy armbian-zram-config. Check for errors or permissions."
        fi
    else
        log_info "armbian-zram-config not found in overlay. Skipping."
    fi
    # --- End of section for copying overlay configuration files

    log_info "--- Finishing custom image customization ---"

} # End of Main function

# Execute the main function
Main "$@"

# Ensure successful exit
exit 0
