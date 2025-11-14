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
   echo "-b     Supply systemd-boot or grub"
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
        b)
            bootloader=$OPTARG;;
        u)
            user=$OPTARG;;
        \?)
            echo "Error: Invalid option"
            usage
            exit;;
    esac
done

echo "** Running chroot post install script **"


# change pacman
echo -e "\t>> Setting up pacman configuration"
sed -i '/#VerbosePkgLists/c\VerbosePkgLists' /etc/pacman.conf
sed -i '/#Color/a\ILoveCandy' /etc/pacman.conf
sed -i '/#Color/c\Color' /etc/pacman.conf

# install packages in chroot
echo -e "\t>> Installing packages"
pacman -Syu 1>/dev/null && \
pacman -S --noconfirm \
    curl \
    git \
    openssh \
    sudo \
    vim \
    zsh \
    1>/dev/null

# give wheel group sudo privileges
echo -e "\t>> Enabling wheel sudo privileges"
sed -i '/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/c\%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers

# add network interface for systemd-networkd
echo -e "\t>> Setting up network configuration"
cat <<'EOF' >> /etc/systemd/network/wired.network
[Match]
Name=enp1s0

[Network]
DHCP=yes
EOF

echo -e "\t>> Setting up SSH configuration"
cat <<'EOF' >> /etc/ssh/sshd_config.d/50-custom.conf
PermitRootLogin no
StrictModes yes
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
PrintMotd yes
EOF


# enable systemd services
echo -e "\t>> Enabling Systemd-networkd, systemd-resolved, systemd-boot-update and sshd"
systemctl enable systemd-networkd.service systemd-resolved.service 1>/dev/null
systemctl enable systemd-boot-update.service 1>/dev/null
systemctl enable sshd.service 1>/dev/null

configuki()
{
    echo -e "\t>> Configuring Unified Kernel Image"
    # sed -i '/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/c\HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)' /etc/mkinitcpio.conf
    echo 'root=/dev/vda2 rw nowatchdog' >> /etc/kernel/cmdline
    echo 'KEYMAP=us' >> /etc/vconsole.conf
    # sed -i "/PRESETS=('default' 'fallback')/c\PRESETS=('default')" /etc/mkinitcpio.d/linux.preset
    sed -i '/default_image/c\#default_image' /etc/mkinitcpio.d/linux.preset
    sed -i '/#default_uki/c\default_uki="/efi/EFI/Linux/arch-linux.efi"' /etc/mkinitcpio.d/linux.preset
    mkinitcpio -P 1>/dev/null
    rm -rf /boot/initramfs*
}

intallgrub()
{
    echo -e "\t>> Setting up and installing Grub"
    pacman -S --noconfirm grub 1>/dev/null
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=grub
    sed -i '/loglevel=3 quiet/c\loglevel=3 nowatchdog'
    grub-mkconfig -o /boot/grub/grub.cfg 1>/dev/null
}

installuki()
{
    echo -e "\t>> Installing UKI without boot loader"
    mkdir -p /efi/EFI/Linux
    configuki
    efibootmgr --create --disk /dev/vda --part 1 --label "Arch Linux" --loader "\EFI\Linux\arch-linux.efi" --unicode
    pacman -S --noconfirm sbctl
    sbctl create-keys
    sbctl enroll-keys -m
    sbctl sign -s /efi/EFI/Linux/arch-linux.efi
}
installsystemdboot()
{
    echo -e "\t>> Installing Systemd-boot"
    bootctl install 1>/dev/null
    configuki
    pacman -S --noconfirm sbctl 1>/dev/null
    sbctl create-keys 1>/dev/null
    sbctl enroll-keys -m 1>/dev/null
    sbctl sign -s /efi/EFI/Linux/arch-linux.efi
    sbctl sign -s /efi/EFI/BOOT/BOOTX64.EFI
    sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi
    sbctl sign -s /usr/lib/systemd/boot/efi/systemd-bootx64.efi -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed
}

case $bootloader in
    grub) # install grub
        installgrub;;
    uki) # install unified kernel image
        installuki;;
    systemd-boot) # install systemd-boot
        installsystemdboot;;
    *)
        echo "No bootloader installed";;
esac

# add user
echo -e "\t>> Configuring user"
useradd -mG wheel -s /usr/bin/zsh "$user"
touch /home/$user/.zshrc
chown "$user":"$user" /home/"$user"/.zshrc
passwd "$user"

echo "** DONE **"
