#!/usr/bin/env bash

set -euo pipefail

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root!"
    exit 1
fi

echo "** Running post install script for root **"

# install packages
echo -e "\t>> Installing packages"
pacman -S --noconfirm \
    bat \
    btop \
    eza \
    man-db \
    man-pages \
    neovim \
    plocate \
    polkit \
    podman \
    podman-compose \
    reflector \
    zoxide \
    1>/dev/null

# change reflector settings
echo -e "\t>> Installing Reflector config and enabling timer"
cat <<'EOF' > /etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--protocol https
--country Netherlands
--latest 5
--sort rate
EOF
systemctl enable reflector.timer 1>/dev/null


# change default settings
echo -e "\t>> Setting timezone, locales and hostname"
timedatectl set-timezone Europe/Amsterdam 1>/dev/null
timedatectl set-ntp true 1>/dev/null
hostnamectl set-hostname archvm 1>/dev/null
localectl set-keymap us 1>/dev/null
localectl set-locale en_US.UTF-8 1>/dev/null

echo "** DONE **"
