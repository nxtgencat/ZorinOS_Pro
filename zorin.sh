#!/usr/bin/env bash

# Script metadata
SCRIPT_NAME="Zorin OS Pro Installation Script"
SCRIPT_VERSION="1.0-beta"
SCRIPT_AUTHORS=("nxtgencat" "NamelessNanasi PEAKYCOMMAND")

readonly ZORINCONF_URL="https://github.com/nxtgencat/zorinos/raw/refs/heads/main/zorinconf.xnt"
readonly ZORIN_TEMP_DIR="$(pwd)/.temp"

trap "echo 'Cleaning up...'; rm -rf $ZORIN_TEMP_DIR" EXIT

# Function to detect Zorin OS version and codename
detect_zorin_version() {
    # Check if the os-release file exists
    if [[ ! -f "/etc/os-release" ]]; then
        error_exit "Unable to detect Zorin OS version: /etc/os-release not found"
    fi

    # Source the os-release file
    source /etc/os-release

    # Validate that this is Zorin OS
    if [[ "$ID" != "zorin" ]]; then
        error_exit "This script is only for Zorin OS"
    fi

    # Extract major version
    version="${VERSION_ID%%.*}"

    # Validate version
    if [[ "$version" != "16" && "$version" != "17" ]]; then
        error_exit "Unsupported Zorin OS version: $version"
    fi

    # Use VERSION_CODENAME from os-release
    codename="${VERSION_CODENAME}"

    # Validate codename
    if [[ -z "$codename" ]]; then
        error_exit "Unable to determine Ubuntu codename"
    fi

    echo "$version" "$codename"
}

# Function to generate core package list
generate_core_packages() {
    local version="$1"
    local core_packages=(
        zorin-appearance
        zorin-appearance-layouts-shell-core
        zorin-appearance-layouts-shell-premium
        zorin-appearance-layouts-support
        zorin-auto-theme
        zorin-icon-themes
        zorin-os-artwork
        zorin-os-keyring
        zorin-os-premium-keyring
        zorin-os-wallpapers
        zorin-os-pro
        zorin-os-pro-wallpapers
    )

    # Add version-specific wallpaper packages
    core_packages+=(
        "zorin-os-wallpapers-${version}"
        "zorin-os-pro-wallpapers-${version}"
    )

    printf '%s\n' "${core_packages[@]}"
}

# Function to generate extended package list
generate_extended_packages() {
    local version="$1"
    local core_packages
    mapfile -t core_packages < <(generate_core_packages "$version")

    local extended_packages=(
        "${core_packages[@]}"
        zorin-additional-drivers-checker
        zorin-connect
        zorin-desktop-session
        zorin-desktop-themes
        zorin-exec-guard
        zorin-exec-guard-app-db
        zorin-gnome-tour-autostart
        zorin-os-default-settings
        zorin-os-docs
        zorin-os-file-templates
        zorin-os-minimal
        zorin-os-overlay
        zorin-os-printer-test-page
        zorin-os-pro-creative-suite
        zorin-os-pro-productivity-apps
        zorin-os-restricted-addons
        zorin-os-standard
        zorin-os-tour-video
        zorin-os-upgrader
        zorin-sound-theme
        zorin-windows-app-support-installation-shortcut
    )

    printf '%s\n' "${extended_packages[@]}"
}

# Create the Zorin temporary directory
create_temp_dir() {
    echo "Creating temporary directory at ${ZORIN_TEMP_DIR}..."
    
    # Check if the directory already exists
    if [[ ! -d "${ZORIN_TEMP_DIR}" ]]; then
        mkdir -p "${ZORIN_TEMP_DIR}" || error_exit "Failed to create temporary directory at ${ZORIN_TEMP_DIR}"
    else
        echo "Temporary directory already exists. Proceeding..."
    fi
}

# Download zorinconf.xnt and extract it
download_and_extract_zorinconf() {
    echo "Downloading Configs..."
    local archive_name="zorinconf.xnt"

    # Download the tar archive
    curl -o "${ZORIN_TEMP_DIR}/$archive_name" -L "${ZORINCONF_URL}" || error_exit "Failed to download zorinconf.xnt"

    # Extract the tar archive
    tar -xf "${ZORIN_TEMP_DIR}/$archive_name" -C "${ZORIN_TEMP_DIR}" || error_exit "Failed to extract zorinconf.xnt"
}

# Print script header
print_header() {
    echo "|ZORIN-OS-PRO| |Script v${SCRIPT_VERSION}| |Overhauled By ${SCRIPT_AUTHORS[0]}| |original by ${SCRIPT_AUTHORS[1]}|"
    echo ""
}

# Error handling function
error_exit() {
    echo "Error: $1" >&2
    echo "Please read the GitHub documentation: https://github.com/nxtgencat/zorinos" >&2
    exit 1
}

# Generate repository list
generate_sources_list() {
    local version="$1"
    local codename="$2"
    local repositories=(
        "stable"
        "patches"
        "apps"
        "drivers"
        "premium"
    )

    # Create temporary sources list
    local sources_list_path="/etc/apt/sources.list.d/zorin.list"
    
    # Use sudo to write to the file
    {
        for repo in "${repositories[@]}"; do
            echo "deb https://packages.zorinos.com/${repo} ${codename} main"
            echo "deb-src https://packages.zorinos.com/${repo} ${codename} main"
            
            # Special case for drivers repository
            if [[ "$repo" == "drivers" ]]; then
                echo "deb https://packages.zorinos.com/${repo} ${codename} main restricted"
                echo "deb-src https://packages.zorinos.com/${repo} ${codename} main restricted"
            fi
        done
    } | sudo tee "$sources_list_path" > /dev/null || error_exit "Failed to generate sources list"
}

# Parse command line arguments
parse_arguments() {
    local OPTIND
    while getopts "XU" opt; do
        case $opt in
            X) extras="true" ;;
            U) 
                unattended="true"
                apt_no_confirm="-y"
                ;;
            *) error_exit "Invalid option" ;;
        esac
    done
}

# Ensure sudo access
validate_sudo_access() {
    echo "Please Enter your sudo password!"
    sudo -v || error_exit "Unable to obtain sudo privileges"
}

# Install essential packages
install_dependencies() {
    echo "Preparing to install dependencies..."
    sudo apt-get install "${apt_no_confirm:-}" ca-certificates || error_exit "Failed to install ca-certificates"
    
    if [[ "${unattended:-false}" == "false" ]]; then
        sudo apt-get install "${apt_no_confirm:-}" aptitude || error_exit "Failed to install aptitude"
    fi
}

# Add Zorin package keys
add_package_keys() {
    echo "Adding Zorin's Package Keys..."
    sudo \cp -n "${ZORIN_TEMP_DIR}/zorin_apt-cdrom.gpg" /etc/apt/trusted.gpg.d/ || error_exit "Failed to add apt-cdrom key"
    sudo \cp -n "${ZORIN_TEMP_DIR}/zorin-os-premium.gpg" /etc/apt/trusted.gpg.d/ || error_exit "Failed to add premium key"
    sudo \cp -n "${ZORIN_TEMP_DIR}/zorin-os.gpg" /etc/apt/trusted.gpg.d/ || error_exit "Failed to add Zorin OS key"
}

# Add premium user agent
add_premium_user_agent() {
    echo "Adding premium flags..."
    sudo \cp -f "${ZORIN_TEMP_DIR}/99zorin-os-premium-user-agent" /etc/apt/apt.conf.d/ || error_exit "Failed to add premium user agent"
}

# Add premium content
add_premium_content() {
    echo "Adding premium content..."
    local temp_dir
    temp_dir=$(mktemp -d) || error_exit "Failed to create temporary directory"
    
    trap 'rm -rf "$temp_dir"' EXIT
    
    # Download and install premium keyring
    curl -A 'Zorin OS Premium' https://packages.zorinos.com/premium/pool/main/z/zorin-os-premium-keyring/zorin-os-premium-keyring_1.0_all.deb --output "$temp_dir/zorin-os-premium-keyring_1.0_all.deb" || error_exit "Failed to download premium keyring"
    sudo apt install "${apt_no_confirm:-}" "$temp_dir/zorin-os-premium-keyring_1.0_all.deb" || error_exit "Failed to install premium keyring"
}

# Update packages
update_packages() {
    if [[ "${unattended:-false}" == "false" ]]; then
        sudo aptitude update || error_exit "Failed to update packages with aptitude"
    else
        sudo apt-get update || error_exit "Failed to update packages with apt-get"
    fi
}

# Install packages
install_packages() {
    local version="$1"
    local packages=()
    
    if [[ "${extras:-false}" == "true" ]]; then
        mapfile -t packages < <(generate_extended_packages "$version")
    else
        mapfile -t packages < <(generate_core_packages "$version")
    fi

    if [[ "${unattended:-false}" == "true" ]]; then
        sudo apt-get install "${apt_no_confirm:--y}" "${packages[@]}" || error_exit "Package installation failed"
    else
        sudo aptitude install "${packages[@]}" || error_exit "Package installation failed"
    fi
}

# Main script execution
main() {
    print_header
    parse_arguments "$@"
    
    # Detect Zorin OS version and codename
    read -r version codename < <(detect_zorin_version)
    
    validate_sudo_access
    install_dependencies
    
    create_temp_dir
    download_and_extract_zorinconf

    sleep 2
    generate_sources_list "$version" "$codename"
    
    sleep 2
    add_package_keys
    
    sleep 2
    add_premium_user_agent
    
    sleep 2
    add_premium_content
    
    update_packages
    install_packages "$version"
    
    # Completion message
    echo ""
    echo "All done!"
    echo ""
    echo 'Please Reboot your Zorin Instance... you can do so with "sudo reboot"'
    echo ""
}

# Run the main script with all arguments
main "$@"
