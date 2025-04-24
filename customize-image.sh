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
                PACKAGES_TO_INSTALL="flatpak gnome-software-plugin-flatpak gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager chrome-gnome-shell gnome-clocks gnome-calendar gnome-calculator xdg-utils fonts-liberation" # Added wget (useful for downloads)
                ;;
            noble)
                log_info "Targeting packages for installation in Noble Desktop..."
                # Add packages to install specifically for Noble Desktop
                PACKAGES_TO_INSTALL="flatpak gnome-software-plugin-flatpak gnome-tweaks gnome-shell-extensions gnome-shell-extension-manager chrome-gnome-shell gnome-clocks gnome-calendar gnome-calculator xdg-utils fonts-liberation" # Added wget
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
            # Check if flatpak was installed and if we are on Noble Desktop
            if [[ "$RELEASE" == "noble" && "$BUILD_DESKTOP" == "yes" && "$PACKAGES_TO_INSTALL" == *flatpak* ]]; then
                log_info "Adding Flathub repository for Noble Desktop..."
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
        noble)
            log_info "Targeting packages for removal in Noble..."
            # List packages to remove specifically for Noble
            PACKAGES_TO_REMOVE="synaptic xarchiver mc terminator gdebi"
            ;;
        bookworm)
            log_info "No specific packages targeted for removal in Bookworm."
            # Example: If you wanted to remove something ONLY in bookworm:
            # PACKAGES_TO_REMOVE="some-bookworm-package"
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


    # --- Conditional Examples (Commented Out) ---

    # Example: Execute specific commands for a board (BOARD)
    # if [ "$BOARD" = "orangepi5-plus" ]; then
    #     log_info "Applying specific configuration for Orange Pi 5 Plus..."
    #     # Specific commands here, for example:
    #     # apt install -y pacote-especifico-opi5plus
    #     # echo "dtoverlay=spi-spidev" >> /boot/armbianEnv.txt # Hypothetical example
    # fi

    # --- End of Commented Examples ---


    # Copy files from overlay (example)
    # if [ -f /tmp/overlay/meu-config.conf ]; then
    #     log_info "Copying my-config.conf from overlay..."
    #     cp /tmp/overlay/meu-config.conf /etc/meu-config.conf
    # fi

    log_info "--- Finishing custom image customization ---"

} # End of Main function

# Execute the main function
Main "$@"

# Ensure successful exit
exit 0
