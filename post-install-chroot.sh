#!/usr/bin/env bash

set -euo pipefail

usage()
{
   # Display Help
   echo "Run this script as chroot after base arch install."
   echo
   echo "Syntax: post-install-chroot.sh [-h] [-b grub|systemd-boot, -u USER]"
   echo "options:"
   echo "h      Print this Help."
   echo "-u     Set new username"
   echo
}


# check for root
if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root!"
    exit 1
fi

while getopts ":hb:u:" option; do
    case $option in
        h)
            usage
            exit;;
        u)
            user=$OPTARG;;
        \?)
            echo "Error: Invalid option"
            usage
            exit;;
    esac
done


message()
{
    echo -e "\e[1;31m>> \e[0m$1"
}

message "** Running chroot post install script **"


# change pacman
message "\t>> Setting up pacman configuration"
sed -i '/#VerbosePkgLists/c\VerbosePkgLists' /etc/pacman.conf
sed -i '/#Color/a\ILoveCandy' /etc/pacman.conf
sed -i '/#Color/c\Color' /etc/pacman.conf

# install packages in chroot
message "Installing packages"
pacman -Syu 1>/dev/null && \
pacman -S --noconfirm \
    apparmor \
    curl \
    git \
    lvm2 \
    openssh \
    sudo \
    systemd-ukify \
    vim \
    zsh \
    1>/dev/null

# give wheel group sudo privileges
message "Enabling wheel sudo privileges"
sed -i '/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/c\%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers

# add network interface for systemd-networkd
message "Setting up network configuration"
cat <<'EOF' >> /etc/systemd/network/wired.network
[Match]
Name=enp1s0

[Network]
DHCP=yes
EOF

message "Setting up SSH configuration"
cat <<'EOF' >> /etc/ssh/sshd_config.d/50-custom.conf
PermitRootLogin no
StrictModes yes
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
PrintMotd yes
EOF


# enable systemd services
message "Enabling Systemd-networkd and systemd-resolved"
systemctl enable systemd-networkd.service systemd-resolved.service 1>/dev/null

message "Enabling systemd-boot-update"
systemctl enable systemd-boot-update.service 1>/dev/null

message "Enabling sshd"
systemctl enable sshd.service 1>/dev/null

message "Enabling auditd"
systemctl enable auditd.service 1>/dev/null

message "Enabling apparmor"
systemctl enable apparmor.service 1>/dev/null

secureboot()
{
    message "Creating and enrolling secure boot keys"
    cat <<'EOF' >> /etc/kernel/uki.conf
[UKI]
SecureBootSigningTool=systemd-sbsign
SignKernel=true
SecureBootPrivateKey=/etc/kernel/secure-boot-private-key.pem
SecureBootCertificate=/etc/kernel/secure-boot-certificate.pem
EOF
    ukify genkey --config /etc/kernel/uki.conf 1>/dev/null
    message "Installing and signing boot loader"
    /usr/lib/systemd/systemd-sbsign sign \
    --private-key /etc/kernel/secure-boot-private-key.pem \
    --certificate /etc/kernel/secure-boot-certificate.pem \
    --output /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi
    bootctl install --secure-boot-auto-enroll yes \
    --certificate /etc/kernel/secure-boot-certificate.pem \
    --private-key /etc/kernel/secure-boot-private-key.pem
    echo 'secure-boot-enroll force' >> /efi/loader/loader.conf
}

configuki()
{
    message "Configuring Unified Kernel Image"
    # sed -i '/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/c\HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)' /etc/mkinitcpio.conf
    echo 'root=/dev/vda2 rw audit=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf lockdown=integrity' >> /etc/kernel/cmdline
    echo 'KEYMAP=us' >> /etc/vconsole.conf
    # sed -i "/PRESETS=('default' 'fallback')/c\PRESETS=('default')" /etc/mkinitcpio.d/linux.preset
    sed -i '/default_image/c\#default_image' /etc/mkinitcpio.d/linux.preset
    sed -i '/#default_uki/c\default_uki="/efi/EFI/Linux/arch-linux.efi"' /etc/mkinitcpio.d/linux.preset
    mkinitcpio -P 1>/dev/null
    rm -rf /boot/initramfs*
}

installsystemdboot()
{
    message "Installing Systemd-boot and enabling Secure Boot"
    secureboot
    configuki
}

installsystemdboot

# add user
message "Configuring user"
useradd -mG wheel -s /usr/bin/zsh "$user"
touch /home/$user/.zshrc
chown "$user":"$user" /home/"$user"/.zshrc
passwd "$user"

message "** DONE **"
