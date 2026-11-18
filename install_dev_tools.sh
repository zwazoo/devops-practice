#!/usr/bin/env bash

set -euo pipefail

. /etc/os-release

if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo "Error: Only Ubuntu and Debian are supported."
    exit 1
fi

install_docker() {
    if command -v docker &>/dev/null; then
        echo "Docker is already installed: $(docker --version)"
        return
    fi

    echo "Installing Docker..."

    sudo apt-get update -qq
    sudo apt-get install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL "https://download.docker.com/linux/$ID/gpg" \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/$ID ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable --now docker

    if ! groups "$USER" | grep -qw docker; then
        sudo usermod -aG docker "$USER"
        echo "User '$USER' added to the 'docker' group."
        echo "NOTE: Log out and back in for this change to take effect."
    fi

    echo "Docker installed: $(docker --version)"
}

install_docker_compose() {
    if docker compose version &>/dev/null; then
        echo "Docker Compose is already installed: $(docker compose version)"
        return
    fi

    echo "Installing Docker Compose..."
    sudo apt-get install -y docker-compose-plugin
    echo "Docker Compose installed: $(docker compose version)"
}

install_python() {
    if command -v python3 &>/dev/null &&
        python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))'; then
        echo "Python is already installed: $(python3 --version)"
        return
    fi

    echo "Installing Python 3.9+..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv

    if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))'; then
        echo "Error: Python 3.9+ is required."
        exit 1
    fi

    echo "Python installed: $(python3 --version)"
}

install_django() {
    # Django is installed into an isolated venv, not system-wide.
    # To use it after install: source ~/.local/share/devops-tools/venv/bin/activate
    VENV_DIR="$HOME/.local/share/devops-tools/venv"

    if [[ -x "$VENV_DIR/bin/python" ]] &&
        "$VENV_DIR/bin/python" -c "import django" &>/dev/null; then
        echo "Django is already installed: $("$VENV_DIR/bin/python" -m django --version)"
        return
    fi

    echo "Installing Django..."

    sudo apt-get install -y python3-venv
    mkdir -p "$(dirname "$VENV_DIR")"

    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/python" -m pip install django

    echo "Django installed: $("$VENV_DIR/bin/python" -m django --version)"
}

echo "=== DevOps Tools Installer ==="

install_docker
install_docker_compose
install_python
install_django

echo "=== All tools are ready ==="
echo ""
echo "To activate the Django venv, run:"
echo "  source ~/.local/share/devops-tools/venv/bin/activate"
