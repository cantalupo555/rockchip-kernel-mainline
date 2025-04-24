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
    # if ! apt-get install -y vim git; then
    #     log_error "Failed to install common packages."
    #     exit 1
    # fi

    # Install Desktop-specific packages
    if [ "$BUILD_DESKTOP" = "yes" ]; then
        log_info "Installing Desktop packages (Firefox)..."
        if ! apt-get install -y firefox; then
             log_error "Failed to install Firefox."
             exit 1
        fi
        # Other desktop packages/settings here
    else
        log_info "Skipping Desktop packages (not a Desktop build)."
        # Server packages/settings here (if needed)
        # log_info "Installing Server packages (e.g., apache2)..."
        # if ! apt-get install -y apache2; then
        #      log_error "Failed to install apache2."
        #      exit 1
        # fi
    fi

    # --- Conditional Examples (Commented Out) ---

    # Example: Execute specific commands for a board (BOARD)
    # if [ "$BOARD" = "orangepi5-plus" ]; then
    #     log_info "Applying specific configuration for Orange Pi 5 Plus..."
    #     # Specific commands here, for example:
    #     # apt install -y pacote-especifico-opi5plus
    #     # echo "dtoverlay=spi-spidev" >> /boot/armbianEnv.txt # Hypothetical example
    # fi

    # Example: Install different packages depending on the release (RELEASE)
    # log_info "Checking specific package installation per release..."
    # case "$RELEASE" in
    #     noble)
    #         log_info "Installing package for Noble..."
    #         # apt install -y pacote-versao-noble
    #         ;;
    #     bookworm)
    #         log_info "Installing package for Bookworm..."
    #         # apt install -y pacote-versao-bookworm
    #         ;;
    #     *)
    #         log_info "Release $RELEASE has no specific package configuration in this example."
    #         ;;
    # esac

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
