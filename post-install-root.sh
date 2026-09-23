#!/usr/bin/env bash

set -e

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root!"
    exit 1
fi

message()
{
    echo -e "\e[1;31m>> \e[0m$1"
}

message "** Running post install script for root **"

# change reflector settings
message "Installing Reflector config and enabling timer"
cat <<'EOF' > /etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--protocol https
--country Netherlands
--latest 5
--sort rate
EOF
systemctl enable reflector.timer 1>/dev/null


# change default settings
message "Setting timezone, locales and hostname"
timedatectl set-timezone Europe/Amsterdam 1>/dev/null
timedatectl set-ntp true 1>/dev/null
hostnamectl set-hostname archvm 1>/dev/null
localectl set-keymap us 1>/dev/null
localectl set-locale en_US.UTF-8 1>/dev/null

message "** DONE **"
