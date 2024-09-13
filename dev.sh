#!/usr/bin/env bash
set -e  # Exit immediately if a command exits with a non-zero status

source ~/.bashrc

BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
ENDCOLOR="\e[0m"

output_info() {
    echo -e "${BLUE}$1${ENDCOLOR}"
}

output_success() {
    echo -e "${GREEN}$1${ENDCOLOR}"
}

output_error() {
    echo -e "${RED}$1${ENDCOLOR}"
}

is_installed() {
    command -v "$1" >/dev/null 2>&1
}

output_info "Your current PATH is: $PATH"


# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    output_error "Please run the script as root (e.g., using sudo)."
    exit 1
fi

trap 'rm -f packages.microsoft.gpg flutter_linux_3.19.4-stable.tar.xz get-docker.sh' EXIT

# Step 1: Update, Upgrade, and Autoremove in one step
output_info "Updating system, upgrading packages, and cleaning up..."
apt-get update -qq && apt-get upgrade -qq && apt-get autoremove -qq
output_success "System update, upgrade, and cleanup completed."

# Step 2: Install default packages for development
output_info "Installing default development packages..."
apt-get install -qq curl build-essential make net-tools git wget
output_success "Default packages installed successfully."

# Step 3: Install Gum
if is_installed "gum"; then
    output_success "Gum is already installed. Skipping Gum installation."
else
    output_info "Installing Gum..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list
    apt-get update -qq
    apt-get install -qq gum || { output_error "Gum setup failed."; exit 1; }
    output_success "Gum installed successfully."
fi

# Step 4: Install VS Code
if is_installed "code"; then
    output_success "VS Code is already installed. Skipping VS Code installation."
else
    output_info "Installing VS Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list
    apt-get update -qq
    apt-get install -qq code
    output_success "VS Code installed successfully."
fi

# Step 5: Install Docker
if is_installed "docker"; then
    output_success "Docker is already installed. Skipping Docker installation."
else
    output_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    groupadd docker
    usermod -aG docker $USER
    output_success "Docker installed successfully."
fi

# Step 6: Install Slack (ensure snap is installed)
if ! is_installed "snap"; then
    output_info "Installing snapd..."
    apt-get install -qq snapd
fi

if is_installed "slack"; then
    output_success "Slack is already installed. Skipping Slack installation."
else
    output_info "Installing Slack..."
    snap install slack --classic
    output_success "Slack installed successfully."
fi

# Step 7: Present the user with additional installation options
output_info "Please select the additional tools you want to install:"
ADDITIONAL=$(gum choose --no-limit "flutter" "postman" "go" "nvm")
if [ -z "$ADDITIONAL" ]; then
    output_error "No additional tools selected. Exiting..."
    exit 1
fi

gum confirm "Proceed with install ($ADDITIONAL)?"

# Step 8: Install the selected tools
for tool in $ADDITIONAL; do
    if is_installed "$tool"; then
        output_success "$tool is already installed. Skipping $tool installation."
        continue
    fi

    output_info "Installing $tool..."
    case $tool in
        flutter)
            apt-get install -qq curl git unzip xz-utils zip libglu1-mesa clang cmake git ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
            FLUTTER_VERSION="3.19.4-stable"
            wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_$FLUTTER_VERSION.tar.xz
            mkdir -p ~/Development/sdk
            tar xf flutter_linux_$FLUTTER_VERSION.tar.xz -C ~/Development/sdk/flutter
            rm flutter_linux_$FLUTTER_VERSION.tar.xz
            ;;
        postman)
            snap install postman
            ;;
        go)
            output_error "Go installation is not yet implemented."
            ;;
        nvm)
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
            ;;
        *)
            output_error "Invalid selection."
            ;;
    esac
    output_success "$tool installed successfully."
done

# Step 9: Reboot prompt
if gum confirm "Do you want to reboot now?"; then
    reboot
else
    output_info "Reboot canceled. Exiting script."
fi
