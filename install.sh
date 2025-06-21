#!/usr/bin/env bash

set -e
set -o pipefail

x_set_debian_user_home_dir() {
    if [[ -n "$SUDO_USER" ]]; then
        # Running via sudo, get home directory of the original user
        USER_HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        # Not running via sudo, use current user's home
        USER_HOME_DIR="$HOME"
    fi

    if command -v zsh &> /dev/null; then
        RC_FILE_NAME=".zshrc"
    else
        RC_FILE_NAME=".bashrc"
    fi 
}

x_install_neovim() {
    if type "nvim" &> /dev/null; then
        echo "nvim already installed. Skipping..."
        return 0
    fi

    echo "Installing nvim..."

    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim
    tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    rm nvim-linux-x86_64.tar.gz

    echo "Added nvim to /opt/nvim-linux-x86_64"
   
    if [[ -n "$USER_HOME_DIR" ]]; then
        echo "\$USER_HOME_DIR is missing..."
        exit 1
    fi

    if [[ -n "$RC_FILE_NAME" ]]; then
        echo "\$RC_FILE_NAME is missing..."
        exit 1
    fi

    echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> $USER_HOME_DIR/$RC_FILE_NAME

    echo "Added nvim to \$PATH in ${USER_HOME_DIR}/$RC_FILE_NAME"
}

x_install_debian_packages() {
    PACKAGES_TO_CHECK=(
        "tmux"
        "htop"
        "curl"
        "git"
    )
    PACKAGES_TO_INSTALL=()

    for PACKAGE in "${PACKAGES_TO_CHECK[@]}"; do
        if ! dpkg -s "$PACKAGE" &> /dev/null; then
            echo "Installing $PACKAGE..."
            PACKAGES_TO_INSTALL+=("$PACKAGE")
        else
            echo "$PACKAGE already installed. Skipping..."
        fi
    done

    if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
        return 0
    fi

    sudo apt-get install -y "${PACKAGES_TO_INSTALL[@]}"
}

if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "Script not yet implemented for MacOS..."
    exit 1
elif command -v dpkg &> /dev/null || ([ -f /etc/os-release ] && (grep -q "ID=debian" /etc/os-release || grep -q "ID_LIKE=debian" /etc/os-release || grep -q "ID=ubuntu" /etc/os-release || grep -q "ID_LIKE=ubuntu" /etc/os-release)); then
    x_install_debian_packages
    x_set_debian_user_home_dir
else
    echo "Script not yet implemented for non-MacOS or non-Debian based OS..."
    exit 1
fi

x_install_neovim
