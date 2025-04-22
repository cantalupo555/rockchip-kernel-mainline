#!/bin/bash

# Script to automate building multiple Armbian images
# with different boards, releases, and desktops, followed by server images,
# optimizing cleanup between builds.

# Define the desired variations
BOARDS=("orangepi5" "orangepi5-plus")
RELEASES=("noble" "bookworm")
DESKTOPS=("gnome" "xfce" "cinnamon") # Only for the desktop section

# Fixed base parameters for all builds (unless overridden)
BRANCH="mainline"
ROOTFS_TYPE="btrfs"
BTRFS_COMPRESSION="zstd"
DESKTOP_APPGROUPS_SELECTED="browsers,desktop_tools,editors,email,office" # Used only for desktop builds
DESKTOP_ENVIRONMENT_CONFIG_NAME="config_base" # Used only for desktop builds
ENABLE_EXTENSIONS="mesa-vpu"
COMPRESS_OUTPUTIMAGE="xz"
IMAGE_XZ_COMPRESSION_RATIO="6"
INSTALL_HEADERS="yes"
KERNEL_CONFIGURE="no"
BUILD_MINIMAL="no"
KERNEL_BTF="yes" # Forcing BTF=yes as requested
EXPERT="yes"

# --- Global Variables ---
SCRIPT_DIR=""
FIRST_RUN=true
prev_board=""
prev_release=""
# prev_desktop is not needed for the current cleanup logic
SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()

# --- Helper Functions ---
log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

setup_environment() {
    log_msg "Setting up environment..."
    # Ensure we are in the correct directory (where compile.sh should be)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    cd "$SCRIPT_DIR" || { log_msg "ERROR: Failed to change directory to $SCRIPT_DIR. Exiting."; exit 1; }
    log_msg "Current directory set to: $SCRIPT_DIR"
}

ensure_build_dir() {
    log_msg "Ensuring Armbian build directory exists..."
    # Check if the build directory exists, if not, clone the Armbian build framework
    if [ ! -d "build" ]; then
        log_msg "--- Build directory not found. Cloning Armbian build framework... ---"
        if git clone https://github.com/armbian/build.git; then
            log_msg "--- Armbian build framework cloned successfully. ---"
        else
            log_msg "### ERROR: Failed to clone Armbian build framework. Exiting. ###"
            exit 1
        fi
    # Else: Check if compile.sh exists inside build/
    elif [ ! -f "build/compile.sh" ]; then
       log_msg "### ERROR: build/ directory exists, but compile.sh is missing. Please check your Armbian build framework setup. ###"
       exit 1
    else
        log_msg "--- Build directory found. ---"
    fi

    # Now change into the build directory to run compile.sh
    cd build || { log_msg "### ERROR: Failed to change directory to build/. Exiting. ###"; exit 1; }
    log_msg "--- Changed directory to build/ ---"
}

copy_custom_config() {
    log_msg "Copying custom rockchip-rk3588.conf..."
    # Source path is relative to the SCRIPT_DIR (one level up from current 'build' dir)
    SOURCE_CONF="../rockchip-rk3588.conf"
    # Destination path is relative to the current 'build' dir
    DEST_CONF="config/sources/families/rockchip-rk3588.conf"

    if [ -f "$SOURCE_CONF" ]; then
        log_msg "--- Found custom configuration: $SOURCE_CONF ---"
        log_msg "--- Copying to: $DEST_CONF ---"
        if cp -vf "$SOURCE_CONF" "$DEST_CONF"; then
            log_msg "--- Custom configuration copied successfully. ---"
        else
            # Attempt to create the destination directory if it doesn't exist
            DEST_DIR=$(dirname "$DEST_CONF")
            if [ ! -d "$DEST_DIR" ]; then
                log_msg "--- Destination directory $DEST_DIR does not exist. Attempting to create it. ---"
                if mkdir -p "$DEST_DIR"; then
                    log_msg "--- Destination directory created. Retrying copy. ---"
                    if cp -vf "$SOURCE_CONF" "$DEST_CONF"; then
                        log_msg "--- Custom configuration copied successfully after creating directory. ---"
                    else
                        log_msg "### ERROR: Failed to copy custom configuration even after creating directory. Check permissions. Exiting. ###"
                        exit 1
                    fi
                else
                    log_msg "### ERROR: Failed to create destination directory $DEST_DIR. Check permissions. Exiting. ###"
                    exit 1
                fi
            else
                log_msg "### ERROR: Failed to copy custom configuration. Check permissions or paths. Exiting. ###"
                exit 1
            fi
        fi
    else
        log_msg "### WARNING: Custom configuration file '$SOURCE_CONF' not found next to the script. ###"
        log_msg "###          The default configuration from the build framework will be used.      ###"
        # Decide if this should be a fatal error or just a warning.
        # For now, it's just a warning, allowing the build to proceed with the default config.
        # exit 1 # Uncomment this line if the custom config is mandatory for your builds.
    fi
}

run_desktop_builds() {
    log_msg "#####################################################"
    log_msg "###       Starting Desktop Builds                 ###"
    log_msg "#####################################################"
    log_msg "Boards: ${BOARDS[*]}"
    log_msg "Releases: ${RELEASES[*]}"
    log_msg "Desktops: ${DESKTOPS[*]}"
    log_msg "-----------------------------------------------------"

    local BUILD_DESKTOP_DESKTOP="yes" # Parameter for desktop builds
    local board release desktop CLEAN_OPT EXIT_CODE build_id

    for board in "${BOARDS[@]}"; do
      for release in "${RELEASES[@]}"; do
        for desktop in "${DESKTOPS[@]}"; do
          build_id="Desktop: ${board}/${release}/${desktop}"
          log_msg "### Starting Build: $build_id ###"

          CLEAN_OPT=""
          if [ "$FIRST_RUN" = false ]; then
            # Determine appropriate CLEAN_LEVEL based on the previous iteration
            # **DO NOT** clean 'images' to preserve generated images
            if [[ "$board" != "$prev_board" ]]; then
               log_msg "--- Board Change: Cleaning cache, debs ---"
               CLEAN_OPT="CLEAN_LEVEL=cache,debs"
            elif [[ "$release" != "$prev_release" ]]; then
               log_msg "--- Release Change: Cleaning cache ---"
               CLEAN_OPT="CLEAN_LEVEL=cache"
            else
               log_msg "--- Desktop Change: No extra cleaning needed ---"
               CLEAN_OPT=""
            fi
          else
            log_msg "--- First build (Desktop): No cleaning ---"
          fi

          # Assemble and execute the compile.sh command for DESKTOP
          log_msg "--- Executing compile.sh for $build_id ---"
          ./compile.sh BOARD="$board" \
            BRANCH="$BRANCH" \
            BUILD_DESKTOP="$BUILD_DESKTOP_DESKTOP" \
            RELEASE="$release" \
            DESKTOP_ENVIRONMENT="$desktop" \
            ROOTFS_TYPE="$ROOTFS_TYPE" \
            BTRFS_COMPRESSION="$BTRFS_COMPRESSION" \
            DESKTOP_APPGROUPS_SELECTED="$DESKTOP_APPGROUPS_SELECTED" \
            DESKTOP_ENVIRONMENT_CONFIG_NAME="$DESKTOP_ENVIRONMENT_CONFIG_NAME" \
            ENABLE_EXTENSIONS="$ENABLE_EXTENSIONS" \
            COMPRESS_OUTPUTIMAGE="$COMPRESS_OUTPUTIMAGE" \
            IMAGE_XZ_COMPRESSION_RATIO="$IMAGE_XZ_COMPRESSION_RATIO" \
            INSTALL_HEADERS="$INSTALL_HEADERS" \
            KERNEL_CONFIGURE="$KERNEL_CONFIGURE" \
            BUILD_MINIMAL="$BUILD_MINIMAL" \
            KERNEL_BTF="$KERNEL_BTF" \
            EXPERT="$EXPERT" \
            $CLEAN_OPT # Add the determined cleaning option

          # Check the exit status
          EXIT_CODE=$?
          if [ $EXIT_CODE -ne 0 ]; then
            log_msg "### ERROR: Build failed for $build_id (Exit code: $EXIT_CODE) ###"
            FAILED_BUILDS+=("$build_id")
            log_msg "--- Continuing to the next build ---"
          else
            log_msg "### SUCCESS: Build finished for $build_id ###"
            SUCCESSFUL_BUILDS+=("$build_id")
          fi

          FIRST_RUN=false
          prev_board="$board"
          prev_release="$release"

          log_msg "-----------------------------------------------------"
          # Optional short pause
          # sleep 5

        done
      done
    done
}

run_server_builds() {
    log_msg "#####################################################"
    log_msg "###       Starting Server Builds                  ###"
    log_msg "#####################################################"
    log_msg "Boards: ${BOARDS[*]}"
    log_msg "Releases: ${RELEASES[*]}"
    log_msg "-----------------------------------------------------"

    local BUILD_DESKTOP_SERVER="no" # Parameter specific for server builds
    local board release CLEAN_OPT EXIT_CODE build_id

    for board in "${BOARDS[@]}"; do
      for release in "${RELEASES[@]}"; do
        build_id="Server: ${board}/${release}"
        log_msg "### Starting Build: $build_id ###"

        CLEAN_OPT=""
        # The cleanup logic remains the same, comparing with the *last* build done (whether desktop or server)
        # FIRST_RUN will already be false here, so the if/elif/else logic will apply.
        if [[ "$board" != "$prev_board" ]]; then
           log_msg "--- Board Change: Cleaning cache, debs ---"
           CLEAN_OPT="CLEAN_LEVEL=cache,debs"
        elif [[ "$release" != "$prev_release" ]]; then
           log_msg "--- Release Change: Cleaning cache ---"
           CLEAN_OPT="CLEAN_LEVEL=cache"
        else
           # Case where the last build was a desktop of the same board/release
           log_msg "--- Same Board/Release as last build: Cleaning cache (to remove desktop) ---"
           CLEAN_OPT="CLEAN_LEVEL=cache" # Clean the cache from the previous desktop
        fi

        # Assemble and execute the compile.sh command for SERVER
        log_msg "--- Executing compile.sh for $build_id ---"
        ./compile.sh BOARD="$board" \
          BRANCH="$BRANCH" \
          BUILD_DESKTOP="$BUILD_DESKTOP_SERVER" \
          RELEASE="$release" \
          ROOTFS_TYPE="$ROOTFS_TYPE" \
          BTRFS_COMPRESSION="$BTRFS_COMPRESSION" \
          ENABLE_EXTENSIONS="$ENABLE_EXTENSIONS" \
          COMPRESS_OUTPUTIMAGE="$COMPRESS_OUTPUTIMAGE" \
          IMAGE_XZ_COMPRESSION_RATIO="$IMAGE_XZ_COMPRESSION_RATIO" \
          INSTALL_HEADERS="$INSTALL_HEADERS" \
          KERNEL_CONFIGURE="$KERNEL_CONFIGURE" \
          BUILD_MINIMAL="$BUILD_MINIMAL" \
          KERNEL_BTF="$KERNEL_BTF" \
          EXPERT="$EXPERT" \
          $CLEAN_OPT # Add the determined cleaning option

        # Check the exit status
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
          log_msg "### ERROR: Build failed for $build_id (Exit code: $EXIT_CODE) ###"
          FAILED_BUILDS+=("$build_id")
          log_msg "--- Continuing to the next build ---"
        else
          log_msg "### SUCCESS: Build finished for $build_id ###"
          SUCCESSFUL_BUILDS+=("$build_id")
        fi

        # Update variables for the next iteration (whatever it may be)
        prev_board="$board"
        prev_release="$release"

        log_msg "-----------------------------------------------------"
        # Optional short pause
        # sleep 5

      done
    done
}

print_summary() {
    log_msg "#####################################################"
    log_msg "### Build Summary                                 ###"
    log_msg "#####################################################"
    log_msg "Successful Builds (${#SUCCESSFUL_BUILDS[@]}):"
    if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
        printf " - %s\n" "${SUCCESSFUL_BUILDS[@]}"
    else
        echo " - None"
    fi
    log_msg "-----------------------------------------------------"
    log_msg "Failed Builds (${#FAILED_BUILDS[@]}):"
    if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
      printf " - %s\n" "${FAILED_BUILDS[@]}"
    else
      echo " - None"
    fi
    log_msg "#####################################################"
}

# --- Main Execution ---
main() {
    setup_environment
    ensure_build_dir
    copy_custom_config
    run_desktop_builds
    run_server_builds
    print_summary

    # Decide the final exit code
    if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
      log_msg "Exiting with error code 1 due to build failures."
      exit 1 # Exit with error if any build failed
    else
      log_msg "All builds completed successfully. Exiting with code 0."
      exit 0 # Exit with success if all passed
    fi
}

# Execute main function
main
