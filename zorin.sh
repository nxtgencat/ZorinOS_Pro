#!/usr/bin/env bash

# Constants for URLs
readonly PACKAGES_BASE_URL="https://packages.zorinos.com"
readonly PREMIUM_KEYRING_URL="${PACKAGES_BASE_URL}/premium/pool/main/z/zorin-os-premium-keyring/zorin-os-premium-keyring_1.0_all.deb"
readonly GITHUB_DOCUMENTATION_URL="https://github.com/NanashiTheNameless/Zorin-OS-Pro/"
readonly ZORINCONF_URL="https://github.com/nxtgencat/zorinos/raw/refs/heads/main/zorinconf.xnt"

# Constants for File Paths
readonly OS_RELEASE_FILE="/etc/os-release"
readonly SOURCES_LIST_PATH="/etc/apt/sources.list.d/zorin.list"
readonly APT_TRUSTED_GPGS_DIR="/etc/apt/trusted.gpg.d"
readonly APT_CONF_DIR="/etc/apt/apt.conf.d"
readonly ZORIN_TEMP_DIR="$(pwd)/.temp"

# Repositories
readonly REPOSITORIES=(
    "stable"
    "patches"
    "apps"
    "drivers"
    "premium"
)

# Script metadata
readonly SCRIPT_NAME="Zorin OS Pro Installation Script"
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_AUTHORS=("nxtgencat" "NamelessNanasi/NanashiTheNameless" "PEAKYCOMMAND")

# Function to detect Zorin OS version and codename
detect_zorin_version() {
    if [[ ! -f "${OS_RELEASE_FILE}" ]]; then
        error_exit "Unable to detect Zorin OS version: ${OS_RELEASE_FILE} not found"
    fi

    source "${OS_RELEASE_FILE}"

    if [[ "$ID" != "zorin" ]]; then
        error_exit "This script is only for Zorin OS"
    fi

    version="${VERSION_ID%%.*}"

    if [[ "$version" != "16" && "$version" != "17" ]]; then
        error_exit "Unsupported Zorin OS version: $version"
    fi

    codename="${VERSION_CODENAME}"

    if [[ -z "$codename" ]]; then
        error_exit "Unable to determine Ubuntu codename"
    fi

    echo "$version" "$codename"
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

# Print script header
print_header() {
    echo "|ZORIN-OS-PRO| |Script v${SCRIPT_VERSION}| |Overhauled By ${SCRIPT_AUTHORS[0]}| |original by ${SCRIPT_AUTHORS[1]}|"
    echo ""
}

# Error handling function
error_exit() {
    echo "Error: $1" >&2
    echo "Please read the GitHub documentation: ${GITHUB_DOCUMENTATION_URL}" >&2
    exit 1
}

# Generate repository list
generate_sources_list() {
    local version="$1"
    local codename="$2"

    {
        for repo in "${REPOSITORIES[@]}"; do
            echo "deb ${PACKAGES_BASE_URL}/${repo} ${codename} main"
            echo "deb-src ${PACKAGES_BASE_URL}/${repo} ${codename} main"
            if [[ "$repo" == "drivers" ]]; then
                echo "deb ${PACKAGES_BASE_URL}/${repo} ${codename} main restricted"
                echo "deb-src ${PACKAGES_BASE_URL}/${repo} ${codename} main restricted"
            fi
        done
    } | sudo tee "${SOURCES_LIST_PATH}" > /dev/null || error_exit "Failed to generate sources list"
}

# Ensure sudo access
validate_sudo_access() {
    echo "Please Enter your sudo password!"
    sudo -v || error_exit "Unable to obtain sudo privileges"
}

# Install essential packages
install_dependencies() {
    echo "Preparing to install dependencies..."
    sudo apt-get install "${apt_no_confirm:-}" ca-certificates curl || error_exit "Failed to install required packages"
}

# Add Zorin package keys
add_package_keys() {
    echo "Adding Zorin's Package Keys..."
    sudo \cp -n "${ZORIN_TEMP_DIR}/zorin_apt-cdrom.gpg" "${APT_TRUSTED_GPGS_DIR}/" || error_exit "Failed to add apt-cdrom key"
    sudo \cp -n "${ZORIN_TEMP_DIR}/zorin-os-premium.gpg" "${APT_TRUSTED_GPGS_DIR}/" || error_exit "Failed to add premium key"
    sudo \cp -n "${ZORIN_TEMP_DIR}/zorin-os.gpg" "${APT_TRUSTED_GPGS_DIR}/" || error_exit "Failed to add Zorin OS key"
}


# Download zorinconf.xnt and extract it
download_and_extract_zorinconf() {
    echo "Downloading Configs..."
    local archive_name="zorinconf.xnt"

    # Download the tar archive
    curl -o "$archive_name" -L "${ZORINCONF_URL}" || error_exit "Failed to download zorinconf.xnt"

    # Extract the tar archive
    tar -xf "$archive_name" -C "${ZORIN_TEMP_DIR}" || error_exit "Failed to extract zorinconf.xnt"
}


# Add premium user agent
add_premium_user_agent() {
    echo "Adding premium flags..."
    sudo \cp -f "${ZORIN_TEMP_DIR}/99zorin-os-premium-user-agent" "${APT_CONF_DIR}/" || error_exit "Failed to add premium user agent"
}

# Add premium content
add_premium_content() {
    echo "Adding premium content..."

    trap 'rm -rf "${ZORIN_TEMP_DIR}"' EXIT

    curl -A 'Zorin OS Premium' "${PREMIUM_KEYRING_URL}" --output "${ZORIN_TEMP_DIR}/zorin-os-premium-keyring_1.0_all.deb" || error_exit "Failed to download premium keyring"
    sudo apt install "${apt_no_confirm:-}" "${ZORIN_TEMP_DIR}/zorin-os-premium-keyring_1.0_all.deb" || error_exit "Failed to install premium keyring"
}

# Update packages
update_packages() {
    sudo apt-get update || error_exit "Failed to update packages"
}

# Main script execution
main() {
    print_header
    read -r version codename < <(detect_zorin_version)
    validate_sudo_access
    install_dependencies
    create_temp_dir
    download_and_extract_zorinconf
    generate_sources_list "$version" "$codename"
    add_package_keys
    add_premium_user_agent
    add_premium_content
    update_packages
    echo "\n All done!"
    echo ""
    echo ""
    echo 'Please Reboot your Zorin Instance... you can do so with "sudo reboot"'
    echo ""
}

main "$@"
