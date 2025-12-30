#!/bin/bash

# Script to automate building multiple Armbian images
# with different boards, releases, and desktops, followed by server images,
# optimizing cleanup between builds.

# Available options for selection
AVAILABLE_BOARDS=("orangepi5" "orangepi5-plus" "rock-5a" "rock-5b" "rock-5b-plus")
AVAILABLE_RELEASES_DESKTOP=("noble" "questing")
AVAILABLE_RELEASES_SERVER=("noble" "questing" "trixie")
DESKTOPS=("gnome") # Only for the desktop section

# Selected options (populated by interactive menus)
BOARDS=()
RELEASES=()
RELEASES_SERVER=()

# Fixed base parameters for all builds (unless overridden)
BRANCH="mainline"
ROOTFS_TYPE="btrfs"
BTRFS_COMPRESSION="zstd"
DESKTOP_APPGROUPS_SELECTED="" # Used only for desktop builds
DESKTOP_ENVIRONMENT_CONFIG_NAME="config_base" # Used only for desktop builds
ENABLE_EXTENSIONS="mesa-vpu"
COMPRESS_OUTPUTIMAGE="sha,zstd"
IMAGE_ZSTD_COMPRESSION_RATIO=9
INSTALL_HEADERS="yes"
KERNEL_CONFIGURE="no"
BUILD_MINIMAL="no"
KERNEL_BTF="yes" # Forcing BTF=yes as requested
EXPERT="yes"
PROGRESS_LOG_TO_FILE="yes" # Enable progress logging to file
NO_HOST_RELEASE_CHECK="no" # Skip host release check

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

# Multi-select menu function
# Usage: multiselect "prompt" options_array selected_array
# Returns selected items in the MULTISELECT_RESULT array
MULTISELECT_RESULT=()

multiselect() {
    local prompt="$1"
    shift
    local -a options=("$@")
    local -a selected=()
    local -a checked=()
    local cur=0
    local count=${#options[@]}

    # Initialize all as unchecked
    for ((i=0; i<count; i++)); do
        checked[i]=0
    done

    # Hide cursor
    tput civis

    # Print initial menu
    echo "$prompt"
    echo "(Use arrow keys to navigate, SPACE to select, ENTER to confirm)"
    echo ""

    # Function to print menu
    print_menu() {
        for ((i=0; i<count; i++)); do
            # Move cursor to correct line
            if ((i == cur)); then
                echo -n "> "
            else
                echo -n "  "
            fi

            if ((checked[i] == 1)); then
                echo "[x] ${options[i]}"
            else
                echo "[ ] ${options[i]}"
            fi
        done
    }

    print_menu

    # Read user input
    while true; do
        # Read single keypress
        read -rsn1 key

        # Check for escape sequences (arrow keys)
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case $key in
                '[A') # Up arrow
                    ((cur > 0)) && ((cur--))
                    ;;
                '[B') # Down arrow
                    ((cur < count-1)) && ((cur++))
                    ;;
            esac
        elif [[ $key == "" ]]; then # Enter key
            break
        elif [[ $key == " " ]]; then # Space key
            if ((checked[cur] == 1)); then
                checked[cur]=0
            else
                checked[cur]=1
            fi
        fi

        # Move cursor up to redraw menu
        for ((i=0; i<count; i++)); do
            tput cuu1
            tput el
        done

        print_menu
    done

    # Show cursor
    tput cnorm

    # Build result array
    MULTISELECT_RESULT=()
    for ((i=0; i<count; i++)); do
        if ((checked[i] == 1)); then
            MULTISELECT_RESULT+=("${options[i]}")
        fi
    done

    echo ""
}

# Single select menu function
# Usage: singleselect "prompt" options_array
# Returns selected item in SINGLESELECT_RESULT
SINGLESELECT_RESULT=""

singleselect() {
    local prompt="$1"
    shift
    local -a options=("$@")
    local cur=0
    local count=${#options[@]}

    # Hide cursor
    tput civis

    echo "$prompt"
    echo "(Use arrow keys to navigate, ENTER to select)"
    echo ""

    # Function to print menu
    print_menu() {
        for ((i=0; i<count; i++)); do
            if ((i == cur)); then
                echo "> ${options[i]}"
            else
                echo "  ${options[i]}"
            fi
        done
    }

    print_menu

    while true; do
        read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case $key in
                '[A') ((cur > 0)) && ((cur--)) ;;
                '[B') ((cur < count-1)) && ((cur++)) ;;
            esac
        elif [[ $key == "" ]]; then
            break
        fi

        for ((i=0; i<count; i++)); do
            tput cuu1
            tput el
        done

        print_menu
    done

    tput cnorm
    SINGLESELECT_RESULT="${options[cur]}"
    echo ""
}

# Select boards interactively
select_boards() {
    log_msg "Select boards to build:"
    echo ""
    multiselect "Available boards:" "${AVAILABLE_BOARDS[@]}"
    BOARDS=("${MULTISELECT_RESULT[@]}")

    if [ ${#BOARDS[@]} -eq 0 ]; then
        log_msg "### ERROR: No boards selected. Exiting. ###"
        exit 1
    fi

    log_msg "Selected boards: ${BOARDS[*]}"
}

# Select releases for desktop
select_releases_desktop() {
    log_msg "Select releases for Desktop builds:"
    echo ""
    multiselect "Available releases (Desktop - GNOME):" "${AVAILABLE_RELEASES_DESKTOP[@]}"
    RELEASES=("${MULTISELECT_RESULT[@]}")

    if [ ${#RELEASES[@]} -eq 0 ]; then
        log_msg "### ERROR: No releases selected for Desktop. Exiting. ###"
        exit 1
    fi

    log_msg "Selected Desktop releases: ${RELEASES[*]}"
}

# Select releases for server
select_releases_server() {
    log_msg "Select releases for Server builds:"
    echo ""
    multiselect "Available releases (Server):" "${AVAILABLE_RELEASES_SERVER[@]}"
    RELEASES_SERVER=("${MULTISELECT_RESULT[@]}")

    if [ ${#RELEASES_SERVER[@]} -eq 0 ]; then
        log_msg "### ERROR: No releases selected for Server. Exiting. ###"
        exit 1
    fi

    log_msg "Selected Server releases: ${RELEASES_SERVER[*]}"
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

# --- Helper function to copy a single file or directory with directory creation and error handling ---
_copy_item() {
    local source_path="$1"
    local dest_path="$2"
    local dest_dir
    local cp_cmd=""

    # Check if source item exists
    if [ ! -e "$source_path" ]; then
        log_msg "### WARNING: Source item '$source_path' not found. Skipping copy. ###"
        # Return 0 because a missing source might be acceptable (like the default conf)
        return 0
    fi

    log_msg "--- Found custom item: $source_path ---"
    log_msg "--- Attempting to copy to: $dest_path ---"

    # Determine the correct cp command
    if [ -d "$source_path" ]; then
        # Use -a (archive) to preserve attributes, -r (recursive), -f (force overwrite)
        cp_cmd="cp -arf"
        log_msg "--- Source is a directory, using '$cp_cmd' ---"
    elif [ -f "$source_path" ]; then
        # Use -v (verbose), -f (force overwrite)
        cp_cmd="cp -vf"
        log_msg "--- Source is a file, using '$cp_cmd' ---"
    else
        log_msg "### ERROR: Source '$source_path' exists but is not a regular file or directory. Skipping copy. ###"
        return 1 # Indicate failure
    fi

    # Attempt initial copy
    if $cp_cmd "$source_path" "$dest_path"; then
        log_msg "--- Item copied successfully. ---"
        return 0
    else
        # If copy failed, check if destination directory's parent exists
        dest_dir=$(dirname "$dest_path")
        if [ ! -d "$dest_dir" ]; then
            log_msg "--- Destination directory '$dest_dir' does not exist. Attempting to create it. ---"
            if mkdir -p "$dest_dir"; then
                log_msg "--- Destination directory created. Retrying copy. ---"
                if $cp_cmd "$source_path" "$dest_path"; then
                    log_msg "--- Item copied successfully after creating directory. ---"
                    return 0
                else
                    log_msg "### ERROR: Failed to copy item '$source_path' even after creating directory '$dest_dir'. Check permissions. ###"
                    return 1 # Indicate failure
                fi
            else
                log_msg "### ERROR: Failed to create destination directory '$dest_dir'. Check permissions. ###"
                return 1 # Indicate failure
            fi
        else
            # Directory exists, but initial copy failed
            log_msg "### ERROR: Failed to copy item '$source_path' to '$dest_path'. Destination directory exists, check permissions or other issues. ###"
            return 1 # Indicate failure
        fi
    fi
}


copy_custom_config() {
    log_msg "Copying custom configuration files and scripts..."

    # --- ROCKCHIP FAMILY CONFIG ---
    # Source: Custom config file for the RK3588 family.
    local source_conf_rk="../configs/rockchip-rk3588.conf"
    # Destination: Overwrites the default family config within the build framework.
    local dest_conf_rk="config/sources/families/rockchip-rk3588.conf"

    # --- COMPRESS/CHECKSUM SCRIPT ---
    # Source: Custom script for image compression/checksum.
    local source_script_cs="../scripts/compress-checksum.sh"
    # Destination: Overwrites the default script within the build framework's library functions.
    local dest_script_cs="lib/functions/image/compress-checksum.sh"

    # --- CUSTOMIZE SCRIPT ---
    # Source: Custom script for image customization.
    local source_customize_script="../scripts/customize-image.sh"
    # Destination: Placed in userpatches to be executed during image customization.
    local dest_customize_script="userpatches/customize-image.sh"

    # --- DOCKER CONFIG ---
    # Source: Custom configuration for Docker build flags.
    local source_docker_conf="../configs/config-docker.conf"
    # Destination: Placed in userpatches to be sourced by the build framework when using Docker.
    local dest_docker_conf="userpatches/config-docker.conf"

    # --- ZRAM CONFIG OVERLAY ---
    # Source: Custom armbian-zram-config file.
    local source_zram_config="../configs/armbian-zram-config"
    # Destination: Placed in userpatches/overlay to be copied directly to /etc/default/ in the image.
    local dest_zram_config="userpatches/overlay/armbian-zram-config"

    # --- FIREFOX DESKTOP OVERLAY ---
    # Source: Custom firefox.desktop file.
    local source_firefox_desktop="../overlay/firefox.desktop"
    # Destination: Placed in userpatches/overlay to be copied to /usr/share/applications/ in the image.
    local dest_firefox_desktop="userpatches/overlay/firefox.desktop"

    # Copy rockchip-rk3588.conf
    if ! _copy_item "$source_conf_rk" "$dest_conf_rk"; then
        # If _copy_item returned 1 (error), and it wasn't just a missing source warning
        if [ -f "$source_conf_rk" ]; then # Check if the source existed (meaning it was a real copy error)
             log_msg "### FATAL: Error copying $source_conf_rk. Exiting. ###"
             exit 1
        fi
        # If source didn't exist, the warning was already printed by the helper, continue.
    fi

    # Copy compress-checksum.sh
    if ! _copy_item "$source_script_cs" "$dest_script_cs"; then
        # If _copy_item returned 1 (error), and it wasn't just a missing source warning
        if [ -f "$source_script_cs" ]; then # Check if the source existed
             log_msg "### FATAL: Error copying $source_script_cs. Exiting. ###"
             exit 1
        fi
        # If source didn't exist, the warning was already printed by the helper.
        # Decide if a missing compress-checksum.sh is fatal. Assuming it IS required:
        log_msg "### FATAL: Required custom script '$source_script_cs' not found. Exiting. ###"
        exit 1
    fi

    # --- Copy the customize-image.sh script ---
    if ! _copy_item "$source_customize_script" "$dest_customize_script"; then
        # If _copy_item returned 1 (error), and it wasn't just a missing source warning
        if [ -e "$source_customize_script" ]; then # Check if the source file existed
             log_msg "### FATAL: Error copying $source_customize_script. Exiting. ###"
             exit 1
        else
             # If source didn't exist, assume it's required and exit.
             log_msg "### FATAL: Required custom script '$source_customize_script' not found. Exiting. ###"
             exit 1
        fi
    fi

    # --- Copy the config-docker.conf ---
    if ! _copy_item "$source_docker_conf" "$dest_docker_conf"; then
        # If _copy_item returned 1 (error), check if it was a real copy error or missing source
        if [ -e "$source_docker_conf" ]; then # Use -e to check existence (file or dir)
             log_msg "### FATAL: Error copying $source_docker_conf. Exiting. ###"
             exit 1
        else
             # If source didn't exist, assume it's required and exit.
             log_msg "### FATAL: Required custom config '$source_docker_conf' not found. Exiting. ###"
             exit 1
        fi
    fi

    # --- Copy the armbian-zram-config file to overlay ---
    if ! _copy_item "$source_zram_config" "$dest_zram_config"; then
        # If _copy_item returned 1 (error), check if it was a real copy error or missing source
        if [ -e "$source_zram_config" ]; then # Use -e to check existence (file or dir)
             log_msg "### FATAL: Error copying $source_zram_config. Exiting. ###"
             exit 1
        else
             # If source didn't exist, assume it's required and exit.
             log_msg "### FATAL: Required custom config '$source_zram_config' not found. Exiting. ###"
             exit 1
        fi
    fi

    # --- Copy the firefox.desktop file to overlay ---
    if ! _copy_item "$source_firefox_desktop" "$dest_firefox_desktop"; then
        # If _copy_item returned 1 (error), check if it was a real copy error or missing source
        if [ -e "$source_firefox_desktop" ]; then # Use -e to check existence (file or dir)
             log_msg "### FATAL: Error copying $source_firefox_desktop. Exiting. ###"
             exit 1
        else
             # If source didn't exist, assume it's required and exit.
             log_msg "### FATAL: Required custom desktop file '$source_firefox_desktop' not found. Exiting. ###"
             exit 1
        fi
    fi


    log_msg "--- Custom configuration copy process finished. ---"
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
            IMAGE_ZSTD_COMPRESSION_RATIO="$IMAGE_ZSTD_COMPRESSION_RATIO" \
            INSTALL_HEADERS="$INSTALL_HEADERS" \
            KERNEL_CONFIGURE="$KERNEL_CONFIGURE" \
            BUILD_MINIMAL="$BUILD_MINIMAL" \
            KERNEL_BTF="$KERNEL_BTF" \
            EXPERT="$EXPERT" \
            PROGRESS_LOG_TO_FILE="$PROGRESS_LOG_TO_FILE" \
            NO_HOST_RELEASE_CHECK="$NO_HOST_RELEASE_CHECK" \
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
    log_msg "Releases: ${RELEASES_SERVER[*]}"
    log_msg "-----------------------------------------------------"

    local BUILD_DESKTOP_SERVER="no" # Parameter specific for server builds
    local board release CLEAN_OPT EXIT_CODE build_id

    for board in "${BOARDS[@]}"; do
      for release in "${RELEASES_SERVER[@]}"; do
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
          COMPRESS_OUTPUTIMAGE="$COMPRESS_OUTPUTIMAGE" \
          IMAGE_ZSTD_COMPRESSION_RATIO="$IMAGE_ZSTD_COMPRESSION_RATIO" \
          INSTALL_HEADERS="$INSTALL_HEADERS" \
          KERNEL_CONFIGURE="$KERNEL_CONFIGURE" \
          BUILD_MINIMAL="$BUILD_MINIMAL" \
          KERNEL_BTF="$KERNEL_BTF" \
          EXPERT="$EXPERT" \
          PROGRESS_LOG_TO_FILE="$PROGRESS_LOG_TO_FILE" \
          NO_HOST_RELEASE_CHECK="$NO_HOST_RELEASE_CHECK" \
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

    # --- Step 1: Select Build Type ---
    log_msg "#####################################################"
    log_msg "###       Armbian Image Builder                    ###"
    log_msg "#####################################################"
    echo ""

    local build_choice
    singleselect "Select the type of images to build:" \
        "Build Desktop images ONLY" \
        "Build Server images ONLY" \
        "Build BOTH Desktop and Server images" \
        "Quit"

    case "$SINGLESELECT_RESULT" in
        "Build Desktop images ONLY")
            log_msg "--- Option selected: Building Desktop images only ---"
            build_choice="desktop"
            ;;
        "Build Server images ONLY")
            log_msg "--- Option selected: Building Server images only ---"
            build_choice="server"
            FIRST_RUN=true
            prev_board=""
            prev_release=""
            ;;
        "Build BOTH Desktop and Server images")
            log_msg "--- Option selected: Building BOTH Desktop and Server images ---"
            build_choice="both"
            ;;
        "Quit")
            log_msg "--- Build process cancelled by user. Exiting. ---"
            exit 0
            ;;
    esac

    # --- Step 2: Select Boards ---
    echo ""
    select_boards

    # --- Step 3: Select Releases ---
    echo ""
    if [[ "$build_choice" == "desktop" ]]; then
        select_releases_desktop
    elif [[ "$build_choice" == "server" ]]; then
        select_releases_server
    elif [[ "$build_choice" == "both" ]]; then
        select_releases_desktop
        echo ""
        select_releases_server
    fi

    # --- Show Summary Before Building ---
    echo ""
    log_msg "#####################################################"
    log_msg "### Build Configuration Summary                   ###"
    log_msg "#####################################################"
    log_msg "Build Type: $build_choice"
    log_msg "Boards: ${BOARDS[*]}"
    if [[ "$build_choice" == "desktop" || "$build_choice" == "both" ]]; then
        log_msg "Desktop Releases: ${RELEASES[*]}"
    fi
    if [[ "$build_choice" == "server" || "$build_choice" == "both" ]]; then
        log_msg "Server Releases: ${RELEASES_SERVER[*]}"
    fi
    log_msg "#####################################################"
    echo ""

    # Confirm before proceeding
    read -p "Press ENTER to start building or Ctrl+C to cancel..."
    echo ""

    # --- Execute Builds Based on Choice ---
    if [[ "$build_choice" == "desktop" || "$build_choice" == "both" ]]; then
        run_desktop_builds
    fi

    if [[ "$build_choice" == "server" || "$build_choice" == "both" ]]; then
        run_server_builds
    fi
    # --- End Execute Builds ---


    print_summary

    # Decide the final exit code
    if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
      log_msg "Exiting with error code 1 due to build failures."
      exit 1 # Exit with error if any build failed
    else
      # Check if any build was actually executed before declaring total success
      if [[ "$build_choice" == "desktop" || "$build_choice" == "server" || "$build_choice" == "both" ]]; then
          log_msg "All selected builds completed successfully. Exiting with code 0."
          exit 0 # Exit with success if all selected passed
      else
          # Case where the user chose "Quit" or something unexpected happened
          log_msg "No builds were executed or selected. Exiting."
          exit 0 # Or maybe a different exit code if preferred
      fi
    fi
}

# Execute main function
main
