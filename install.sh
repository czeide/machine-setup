#!/usr/bin/env bash

set -e
set -o pipefail

x_install_debian_packages() {
    PACKAGES_TO_CHECK=(
        "tmux"
        "htop"
        "curl"
        "git"
        "gnupg"
        "pass"
        "jq"
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

x_setup_gitconfig() {
    if [[ -z "$USER_HOME_DIR" ]]; then
        echo "\$USER_HOME_DIR is missing..."
        exit 1
    fi

    local gitconfig_path="$USER_HOME_DIR/.gitconfig"

    if [[ -f "$gitconfig_path" ]]; then
        echo "$gitconfig_path already exists. Skipping..."
        return 0
    fi

    echo "Creating $gitconfig_path..."

    cat <<EOF > "$gitconfig_path"
[user]
        name = Czeide Avanzado
        email = 
        signingkey = 
[credential]
        credentialStore = gpg
        helper = /usr/local/bin/git-credential-manager
[commit]
        gpgsign = true
[gpg]
        program = /usr/bin/gpg
EOF

    if [[ -n "$SUDO_USER" ]]; then
        chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$gitconfig_path"
    fi
}

x_install_neovim() {
    local nvim_os="nvim-linux"
    local nvim_arch="x86_64"
    local nvim_dir_path="/opt/$nvim_os-$nvim_arch"
    local nvim_bin_file="$nvim_dir_path/bin/nvim"

    if [[ -d "$nvim_dir_path" && -f "$nvim_bin_file" ]]; then
        echo "nvim already installed. Skipping..."
        return 0
    fi

    echo "Installing nvim..."

    curl -o /opt/$nvim_os-$nvim_arch.tar.gz -L https://github.com/neovim/neovim/releases/latest/download/$nvim_os-$nvim_arch.tar.gz
    EXPECTED_HASH=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.assets[] | select(.name == "'$nvim_os'-'$nvim_arch'.tar.gz") | .digest | split(":")[1]')
    ACTUAL_HASH=$(sha256sum /opt/$nvim_os-$nvim_arch.tar.gz | cut -d ' ' -f 1)

    if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
        echo "Checksum verification failed for NeoVim! Aborting..."
        rm /opt/$nvim_os-$nvim_arch.tar.gz
        exit 1
    fi
    
    tar -C /opt -xzf /opt/$nvim_os-$nvim_arch.tar.gz
    rm /opt/$nvim_os-$nvim_arch.tar.gz

    echo "Added nvim to $nvim_dir_path"
   
    if [[ -z "$USER_HOME_DIR" ]]; then
        echo "\$USER_HOME_DIR is missing..."
        exit 1
    fi

    if [[ -z "$RC_FILE_NAME" ]]; then
        echo "\$RC_FILE_NAME is missing..."
        exit 1
    fi

    if ! grep -Fq 'export PATH="$PATH:'"$nvim_dir_path"'/bin"' "$USER_HOME_DIR/$RC_FILE_NAME"; then
        echo 'export PATH="$PATH:'"$nvim_dir_path"'/bin"' >> "$USER_HOME_DIR/$RC_FILE_NAME"
        echo "Added nvim to \$PATH in ${USER_HOME_DIR}/$RC_FILE_NAME"
    fi
}

x_setup_gpg_agent_config() {
    if [[ -z "$USER_HOME_DIR" ]]; then
        echo "\$USER_HOME_DIR is missing..."
        exit 1
    fi

    local gnupg_dir="$USER_HOME_DIR/.gnupg"
    local gpg_agent_conf="$gnupg_dir/gpg-agent.conf"

    if [[ ! -d "$gnupg_dir" ]]; then
        echo "Creating $gnupg_dir..."
        mkdir -p "$gnupg_dir"
        chmod 700 "$gnupg_dir"
        
        if [[ -n "$SUDO_USER" ]]; then
            chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$gnupg_dir"
        fi
    fi

    if [[ -f "$gpg_agent_conf" ]]; then
        echo "$gpg_agent_conf already exists. Skipping..."
        return 0
    fi

    echo "Creating $gpg_agent_conf..."

    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        echo "WSL detected. Configuring for WSL..."
        cat <<EOF > "$gpg_agent_conf"
default-cache-ttl 28800
max-cache-ttl 86400
pinentry-program "/mnt/c/Program Files/Git/usr/bin/pinentry.exe"
EOF
    else
        echo "Non-WSL environment detected (assuming Linux)..."
        cat <<EOF > "$gpg_agent_conf"
default-cache-ttl 28800
max-cache-ttl 86400
pinentry-program "/usr/bin/pinentry"
EOF
    fi

    if [[ -n "$SUDO_USER" ]]; then
        chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$gpg_agent_conf"
    fi
}

x_download_and_import_public_gpg() {
    local gpg_email="czeideavanzado@gmail.com"

    if sudo -u "$SUDO_USER" gpg --list-keys "$gpg_email" &> /dev/null; then
        echo "GPG key for $gpg_email already imported. Skipping..."
        return 0
    fi

    local gpg_pub_filename="public.pgp"
    local gpg_pub_file_path="/tmp/$gpg_pub_filename"

    curl -o "$gpg_pub_file_path" -L https://raw.githubusercontent.com/czeide/machine-setup/main/$gpg_pub_filename

    local gpg_pub_checksum_filename="public.pgp.sha256"
    local gpg_pub_checksum_path="/tmp/$gpg_pub_checksum_filename"

    curl -o "$gpg_pub_checksum_path" -L https://raw.githubusercontent.com/czeide/machine-setup/main/$gpg_pub_checksum_filename

    if [[ ! -f "$gpg_pub_file_path" ]]; then
        echo "$gpg_pub_file_path not found. Skipping..."
        return 0
    fi

    if [[ -f "$gpg_pub_checksum_path" ]]; then
        echo "Verifying checksum..."
        if ! (sha256sum --check --status "$gpg_pub_checksum_path"); then
            echo "Checksum verification failed for Public GPG key! Aborting..."
            rm "$gpg_pub_file_path" "$gpg_pub_checksum_path"
            exit 1
        fi
        echo "Checksum verified successfully."
        rm "$gpg_pub_checksum_path"
    else
        echo "Checksum file for public GPG key not found! Aborting..."
        exit 1
    fi

    echo "Importing $gpg_pub_file_path..."

    sudo -u "$SUDO_USER" gpg --import "$gpg_pub_file_path"
    FINGERPRINT=$(sudo -u "$SUDO_USER" gpg --with-colons --show-keys "$gpg_pub_file_path" | awk -F: '/^fpr:/ { print $10; exit }')
    echo "$FINGERPRINT:6:" | sudo -u "$SUDO_USER" gpg --import-ownertrust

    rm "$gpg_pub_file_path"
}

if [[ -z "$SUDO_USER" ]]; then
    echo "Script must be run with sudo..."
    echo "Usage: sudo ./install.sh"
    exit 1
fi

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
x_setup_gitconfig
x_setup_gpg_agent_config
x_download_and_import_public_gpg
